//
//  DataViewController
//  eeg-brainwave-client
//
//  Created by Daniel Marchena on 8/10/18.
//


import UIKit
import CoreBluetooth
import Alamofire
import Charts
import PopupDialog

class DataViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, CBCentralManagerDelegate, MWMDelegate, MindMobileEEGSampleDelegate {
    
    @IBOutlet weak var mainChart: LineChartView!
    @IBOutlet weak var statusImgView: UIImageView!
    @IBOutlet weak var devicePicker: UIPickerView!
    
    @IBOutlet weak var classifierView: UIView!
    @IBOutlet weak var statePicker: UIPickerView!
    @IBOutlet weak var stateSwitch: UISwitch!
    @IBOutlet weak var smoLabel: UILabel!
    @IBOutlet weak var mlPerceptronLabel: UILabel!
    @IBOutlet weak var randomForestLabel: UILabel!
    
    var devicePickerData: [Parameters] = [];
    var statePickerData: [String] = [];
    
    var jwt: String!
    var brainCommands : [Parameters] = []
    var mindWaveDeviceConnected: Bool = false
    
    var meditations : [Int32] = []
    var attentions : [Int32] = []
    var blinks : [Int32] = []
    
    let mindWaveDevice = MWMDevice();
    let sampleInProcess = MindMobileEEGSample();
    
    let central = CBCentralManager()
    
    let serverAddrs: String = ProcessInfo.processInfo.environment["server_addrs"] ?? "localhost:3000";
    var request: URLRequest? = nil;
    
    func updateMainGraph(sample: Parameters){
        meditations.append(sample["meditation"] as! Int32);
        attentions.append(sample["attention"] as! Int32);
        blinks.append(sample["blink"] as! Int32);
        
        let meditationVals = meditations.enumerated().map { (index, element) -> ChartDataEntry in
            return ChartDataEntry(x: Double(index), y: Double(element))
        }
        let attentionVals = attentions.enumerated().map { (index, element) -> ChartDataEntry in
            return ChartDataEntry(x: Double(index), y: Double(element))
        }
        let blinkVals = blinks.enumerated().map { (index, element) -> ChartDataEntry in
            return ChartDataEntry(x: Double(index), y: Double(element))
        }
        
        let meditationsSet = LineChartDataSet(values: meditationVals, label: "Meditation")
        meditationsSet.axisDependency = .left
        meditationsSet.setColor(.blue)
        meditationsSet.setCircleColor(.blue)
        meditationsSet.lineWidth = 2
        meditationsSet.circleRadius = 3
        meditationsSet.fillAlpha = 65/255
        meditationsSet.fillColor = UIColor(red: 51/255, green: 181/255, blue: 229/255, alpha: 1)
        meditationsSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        meditationsSet.drawCircleHoleEnabled = false
        
        let attentionSet = LineChartDataSet(values: attentionVals, label: "Attention")
        attentionSet.axisDependency = .left
        attentionSet.setColor(.red)
        attentionSet.setCircleColor(.red)
        attentionSet.lineWidth = 2
        attentionSet.circleRadius = 3
        attentionSet.fillAlpha = 65/255
        attentionSet.fillColor = .red
        attentionSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        attentionSet.drawCircleHoleEnabled = false
        
        let blinkSet = LineChartDataSet(values: blinkVals, label: "Blink")
        blinkSet.axisDependency = .left
        blinkSet.setColor(.yellow)
        blinkSet.setCircleColor(.yellow)
        blinkSet.lineWidth = 2
        blinkSet.circleRadius = 3
        blinkSet.fillAlpha = 65/255
        blinkSet.fillColor = UIColor.yellow.withAlphaComponent(200/255)
        blinkSet.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
        blinkSet.drawCircleHoleEnabled = false

        let data = LineChartData(dataSets: [meditationsSet, attentionSet, blinkSet])
        data.setValueTextColor(.white)
        data.setValueFont(.systemFont(ofSize: 9))
        
        mainChart.data = data
        mainChart.setVisibleXRangeMaximum(10)
        mainChart.moveViewToX(Double(meditations.count))
    }

    
    func completedSample(sample: Parameters) {
        storeSample(sample: sample)
        sampleInProcess.startNewSample()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case CBManagerState.poweredOn:
            mindWaveDevice.scanDevice()
        default:
            print("BLE Off")
        }
    }
    
    func loadStates() {
        let data = ("{ user { states } }".data(using: .utf8))! as Data
        self.request?.httpBody = data
        
        Alamofire.request(self.request!).responseJSON { response in
            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
            }
            
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                let response = Utils.convertToDictionary(text: utf8Text);
                let user = (response?["data"] as! Parameters)["user"] as! Parameters
                self.statePickerData = user["states"] as! [String]
                if (self.statePickerData.count <= 1) {
                    self.classifierView.isHidden = true;
                } else {
                    self.statePicker.reloadAllComponents();
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        central.delegate = self
        mindWaveDevice.delegate = self
        sampleInProcess.delegate = self
        
        mainChart.chartDescription?.enabled = false
        mainChart.dragEnabled = true
        mainChart.setScaleEnabled(true)
        mainChart.pinchZoomEnabled = true
        
        devicePicker.delegate = self
        devicePicker.dataSource = self
        
        statePicker.delegate = self
        statePicker.dataSource = self
        
        stateSwitch.addTarget(self, action: #selector(self.switchValueDidChange), for: .valueChanged)
        
        statusImgView.image = UIImage(named: "nosignal_v1")
        
        self.navigationItem.hidesBackButton = true
        let newBackButton = UIBarButtonItem(title: "Back", style: UIBarButtonItem.Style.plain, target: self, action: #selector(DataViewController.backButton(sender:)))
        self.navigationItem.leftBarButtonItem = newBackButton
        
        self.request = URLRequest(url: URL(string: "http://"+serverAddrs+"/graphql/")!)
        self.request?.httpMethod = HTTPMethod.post.rawValue
        self.request?.setValue("application/graphql", forHTTPHeaderField: "Content-Type")
        self.request?.setValue("Bearer "+jwt, forHTTPHeaderField: "Authorization")
        
        self.loadStates()
    }
    
    @objc func switchValueDidChange(sender:UISwitch!) {
        let title = "EEG Data Label Trigger"
        var message = ""

        if (sender.isOn) {
            message = "EEG Data started being labeled as: \(statePickerData[statePicker.selectedRow(inComponent: 0)])"
        } else {
            message = "EEG Data stopped being labeled as: \(statePickerData[statePicker.selectedRow(inComponent: 0)])"
        }
        
        let popup = PopupDialog(title: title, message: message)
        let buttonOne = CancelButton(title: "CLOSE") {}
        popup.addButtons([buttonOne])
        self.present(popup, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated) // No need for semicolon
        
        let data = ("{ user { commands { from to valueTo valueFrom type } } }".data(using: .utf8))! as Data
        self.request?.httpBody = data
        
        Alamofire.request(self.request!).responseJSON { response in
            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
            }
    
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                let response = Utils.convertToDictionary(text: utf8Text);
                let user = (response?["data"] as! Parameters)["user"] as! Parameters
                self.brainCommands = user["commands"] as! [Parameters]
            }
        }
    }
    
    @objc func backButton(sender: UIBarButtonItem) {
        if (!self.mindWaveDeviceConnected) {
            self.navigationController?.popViewController(animated: true)
        }
        mindWaveDevice.disconnectDevice();
    }
    
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView == devicePicker {
            return devicePickerData.count
        } else if pickerView == statePicker {
            return statePickerData.count
        }
        return 0;
    }
    
    // The data to return fopr the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        stateSwitch.setOn(false, animated: true);
        if pickerView == devicePicker {
            return devicePickerData[row]["deviceName"] as? String
        } else if pickerView == statePicker {
            return statePickerData[row]
        }
        return "";
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func deviceFound(_ devName: String!, mfgID: String!, deviceID: String!) {
        print("Device Name" + devName! + "\n" + "Manfacturer ID: " + mfgID! + "\n" + "Device ID: " + deviceID!)
        devicePickerData.append(["deviceName": devName+"-"+deviceID, "deviceID": deviceID]);
        devicePicker.reloadAllComponents();
        mindWaveDevice.stopScanDevice()
        mindWaveDevice.connect(deviceID!)
        mindWaveDevice.readConfig()
    }
    
    func didConnect() {
        self.mindWaveDeviceConnected = true;
        print("Connected")
    }
    
    func didDisconnect() {
        self.mindWaveDeviceConnected = false;
        self.navigationController?.popViewController(animated: true)
        //mindWaveDevice.scanDevice()
    }

    func eegBlink(_ blinkValue: Int32) {
        sampleInProcess.addDataToSampe(packetName: "eegBlink", reading: [blinkValue])
    }

    func eegSample(_ sample: Int32) {
        // Not currently used
    }

    func eSense(_ poorSignal: Int32, attention: Int32, meditation: Int32) {
        sampleInProcess.addDataToSampe(packetName: "eSense", reading: [poorSignal, attention, meditation])
    }

    func eegPowerDelta(_ delta: Int32, theta: Int32, lowAlpha: Int32, highAlpha: Int32) {
        sampleInProcess.addDataToSampe(packetName: "eegPowerDelta", reading: [delta, theta, lowAlpha, highAlpha])
    }

    func eegPowerLowBeta(_ lowBeta: Int32, highBeta: Int32, lowGamma: Int32, midGamma: Int32) {
        sampleInProcess.addDataToSampe(packetName: "eegPowerLowBeta", reading: [lowBeta, highBeta, lowGamma, midGamma])
    }
    
    func updateSignalStatus(poorSignal: Int32) {
        if (poorSignal == 0){
            self.statusImgView.image = UIImage(named: "connected_v1")
        } else if (poorSignal > 0 && poorSignal < 50) {
            self.statusImgView.image = UIImage(named: "connecting1_v1")
        } else if (poorSignal >= 50 && poorSignal < 100) {
            self.statusImgView.image = UIImage(named: "connecting2_v1")
        } else if (poorSignal >= 100 && poorSignal < 200) {
            self.statusImgView.image = UIImage(named: "connecting3_v1")
        } else if (poorSignal == 200) {
            self.statusImgView.image = UIImage(named: "nosignal_v1")
        }
    }
    
    func sendCommandToServer(command: Parameters) {
        
        let mutation = "mutation { user { sendCommand(fromCommand: \"\(command["from"]!)\", type: \"\(command["type"]!)\", valueFrom: \"\(command["valueFrom"]!)\", valueTo: \"\(command["valueTo"]!)\" ) } }";
        let data = mutation.data(using: .utf8)! as Data
        self.request?.httpBody = data
        
        Alamofire.request(self.request!).responseJSON { response in
            
            print("Result: \(response.result)")
            
            if let json = response.result.value {
                print("JSON: \(json)")
            }
            
            let title = "Command triggered!"
            let message = "Command \"\(command["from"]!)\"  from \(command["valueFrom"]!) to \(command["valueTo"]!) -> \(command["to"]!)"
            
            let popup = PopupDialog(title: title, message: message)
            let buttonOne = CancelButton(title: "CLOSE") {}
            popup.addButtons([buttonOne])
            self.present(popup, animated: true, completion: nil)
        }
        
    }
    
    func triggerCommandCall(sample: Parameters) {

        self.brainCommands.forEach { (command) in
            if (command["type"] as! String != "bciCommand") {
                return
            }
            
            if (command["from"] as! String == "attention") {
                let currentAttention  = sample["attention"] as! Int32;
                let valueTo = (command["valueTo"] as! NSString).intValue;
                let valueFrom = (command["valueFrom"] as! NSString).intValue;
                if (currentAttention >= valueFrom && currentAttention <= valueTo) {
                    sendCommandToServer(command: command);
                }
            } else if (command["from"] as! String == "blinking") {
                let currentBlink = sample["blink"] as! Int32;
                let valueTo = (command["valueTo"] as! NSString).intValue;
                let valueFrom = (command["valueFrom"] as! NSString).intValue;
                if (currentBlink >= valueFrom && currentBlink <= valueTo) {
                    sendCommandToServer(command: command);
                }
            } else if (command["from"] as! String == "meditation") {
                let meditationAttention = sample["meditation"] as! Int32;
                let valueTo = (command["valueTo"] as! NSString).intValue;
                let valueFrom = (command["valueFrom"] as! NSString).intValue;
                if (meditationAttention >= valueFrom && meditationAttention <= valueTo) {
                    sendCommandToServer(command: command);
                }
            }
        }
    }
    
    func storeEEGData(sample: Parameters) {
        
        var state = ""
        if (!classifierView.isHidden && stateSwitch.isOn) {
            state = statePickerData[statePicker.selectedRow(inComponent: 0)]
        }
        
        let mutation = "mutation { user { sendEEGData (data: { time: \"\(sample["time"]!)\", theta: \(sample["theta"]!), lowAlpha: \(sample["lowAlpha"]!), highAlpha: \(sample["highAlpha"]!), lowBeta: \(sample["lowBeta"]!), highBeta: \(sample["highBeta"]!), lowGamma: \(sample["lowGamma"]!), midGamma: \(sample["midGamma"]!), attention: \(sample["attention"]!), meditation: \(sample["meditation"]!), blink: \(sample["blink"]!), state: \"\(state)\" }) } }";
        
        let data = mutation.data(using: .utf8)! as Data
        self.request?.httpBody = data
        
        Alamofire.request(self.request!).responseJSON { response in
            print("Result: \(response.result)")
            
            if let json = response.result.value {
                print("JSON: \(json)") // serialized json response
            }
        }
    }
    
    func updateEEGDataClassification() {
        
        let mutation = "{ user { latestEEGClassification { SMO, RANDOM_FOREST, MULTILAYER_PERCEPTRON } } }";

        let data = mutation.data(using: .utf8)! as Data
        self.request?.httpBody = data
        
        Alamofire.request(self.request!).responseJSON { response in
            
            print("Result: \(response.result)")
            
            if let json = response.result.value {
                print("JSON: \(json)")
            }
            
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                let response = Utils.convertToDictionary(text: utf8Text);
                let classifiers = ((response?["data"] as! Parameters)["user"] as! Parameters)["latestEEGClassification"] as! Parameters;
                self.mlPerceptronLabel.text = classifiers["MULTILAYER_PERCEPTRON"] as? String
                self.smoLabel.text = classifiers["SMO"] as? String
                self.randomForestLabel.text = classifiers["RANDOM_FOREST"] as? String
            }
        }
    }
    
    func storeSample(sample: Parameters) {
        updateSignalStatus(poorSignal: sample["poorSignal"] as! Int32)
        updateMainGraph(sample: sample)
        triggerCommandCall(sample: sample)
        storeEEGData(sample: sample)
        updateEEGDataClassification()
    }
    
}
