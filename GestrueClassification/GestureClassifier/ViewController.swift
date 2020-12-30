
import UIKit
import CoreMotion
import CoreML

let samplesPerSecond = 25.0
let numberOfFeatures = 6
let windowSize = 20
let windowOffset = 5
let numberOfWindows = windowSize / windowOffset
let bufferSize = windowSize + windowOffset * (numberOfWindows - 1)
let windowSizeAsBytes = windowSize * 8
let windowOffsetAsBytes = windowOffset * 8

let behaviors = ["drive_it","chop_it", "rest_it", "shake_it"]
let show_behavior=["旋转手机！","挥砍手机！","倚靠手机！","摇晃手机！"]
class ViewController: UIViewController {
    
    let model: GestureClassifier = {
        do {
            let config = MLModelConfiguration()
            return try GestureClassifier(configuration: config)
        } catch {
            fatalError("create failed")
        }
    }()

    func predict() {
        if isDataAvaliable && bufferIndex % windowOffset == 0 && bufferIndex + windowOffset <= windowSize {
            let window = bufferIndex / windowOffset
            memcpy(modelInput.dataPointer, buffer.dataPointer.advanced(by: window * windowOffsetAsBytes), windowSizeAsBytes)
            if let prediction = try? model.prediction(features: modelInput, hiddenIn: hiddenIn, cellIn: cellIn){
                hiddenIn = prediction.hiddenOut
                cellIn = prediction.cellOut
                predictions[prediction.activity]! += 1
            }
        }
    }

    @IBOutlet weak var randomLabel: UILabel!
    @IBOutlet weak var resultLabel: UILabel!
    
    @IBAction func get_random_behavior(_ sender: UIButton) {
        print("random_behavior")
        let index = Int.random(in: 0..<behaviors.count)
        randomLabel.text = show_behavior[index]
        print(randomLabel.text ?? "none")
    }
    
    
    @IBAction func startHandler(_ sender: UIButton) {
        behavior_update()
    }
    
    let motionManager = CMMotionManager()
    let queue = OperationQueue()
    let modelInput = makeMultiArray(numberOfSamples: windowSize)!
    let buffer = makeMultiArray(numberOfSamples: bufferSize)!
    
    var bufferIndex = 0
    
    var isDataAvaliable = false
    var predictions = [String:Int]()
    
    var hiddenIn:MLMultiArray?
    var cellIn:MLMultiArray?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
    }

    static private func makeMultiArray (numberOfSamples:Int) -> MLMultiArray? {
        try? MLMultiArray(shape: [1, numberOfSamples, numberOfFeatures] as [NSNumber], dataType: .double)
    }
    private func addToBuffer(_ index: Int, _ feature: Int, _ data: Double){
        buffer[[0, index, feature] as [NSNumber]] = NSNumber(value: data)
    }
    private func buffer(motionData: CMDeviceMotion){
        for offset in [0, windowSize]{
            let index = bufferIndex + offset
            if index >= bufferSize{
                continue
            }
            addToBuffer(index, 0, motionData.rotationRate.x)
            addToBuffer(index, 1, motionData.rotationRate.y)
            addToBuffer(index, 2, motionData.rotationRate.z)
            addToBuffer(index, 3, motionData.userAcceleration.x)
            addToBuffer(index, 4, motionData.userAcceleration.y)
            addToBuffer(index, 5, motionData.userAcceleration.z)
        }
    }
    
    func behavior_update(){
        bufferIndex = 0
        for behavior in behaviors {
            predictions[behavior] = 0
        }
        resultLabel.text = "未检测到动作"
        motionManager.deviceMotionUpdateInterval = 1 / samplesPerSecond
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue, withHandler: {[weak self] data, error in
            guard let self = self, let motionData = data
            else
            {
                print("error")
                return
            }
            self.buffer(motionData: motionData)
            self.bufferIndex = (self.bufferIndex + 1) % windowSize;
            self.predict()
        })
    }
 
 
}

