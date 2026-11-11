import Foundation
import GaeaPluginKit
import GaeaProtocol
import MLXSAMAudio
import MLXServeCore
import MLXToolKit
import SAMAudioPlugin

// The in-process reference for the plugin: SAM-Audio loaded by MLXServeEngine in this process, with the plan, the request and
// the outputs the worker uses (SAMAudioPlugin). The stems are written to --out-dir as <stem>.wav. Not part of the bundle.
//
//   sam-audio-inproc --mixture <wav> --params '<json: describe, stems?, spans?>' [--seed 42] [--models-root <dir>] [--out-dir <dir>]

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}
guard let mixturePath = option("--mixture"), let paramsJSON = option("--params") else {
    FileHandle.standardError.write(Data("usage: sam-audio-inproc --mixture <wav> --params '<json>' [--seed N] [--models-root <dir>] [--out-dir <dir>]\n".utf8))
    exit(2)
}
let mixtureURL = URL(fileURLWithPath: mixturePath)
let params = try JSONDecoder().decode([String: JSONValue].self, from: Data(paramsJSON.utf8))
let modelsRoot = URL(fileURLWithPath: option("--models-root") ?? NSHomeDirectory() + "/Library/Application Support/MLXEngine/Models", isDirectory: true)
let outDir = URL(fileURLWithPath: option("--out-dir") ?? ".", isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let plan = try separatePlan(params: params, seed: UInt64(option("--seed") ?? "") ?? 42, mixtureSeconds: try seconds(of: mixtureURL))
let mixture = try Data(contentsOf: mixtureURL)
let engine = MLXServeEngine(workerBudget: WorkerBudget(ceilingBytes: 64_000_000_000, wiresWeights: false))   // as Gaea sends a worker
await engine.useModelStore(ModelStore(root: modelsRoot))
let id = PackageID(modelID)
_ = try await engine.register(SAMAudioPackage.registration, configuration: SAMAudioConfiguration(), id: id)
var clock = Date()
try await engine.prepare(.audioSeparation, package: id)
let prepare = Date().timeIntervalSince(clock)
clock = Date()
let request = AudioSeparationRequest(audio: Audio(format: .wav, data: mixture, sampleRate: nil, channels: nil),
                                     stems: plan.stems.map { Stem(rawValue: $0) }, targetDescription: plan.describe,
                                     spans: plan.spans, metaData: ["seed": .int(Int(plan.seed))])
guard let response = try await engine.run(request, package: id) as? AudioSeparationResponse else { fatalError("SAM-Audio returned no stems") }
_ = try AudioSeparations.outputs(response, stems: plan.stems, mixture: mixture, outputDir: outDir)
let result: [String: Any] = ["model": modelID, "seed": plan.seed, "describe": plan.describe, "stems": plan.stems,
                             "prepare_s": prepare, "run_s": Date().timeIntervalSince(clock)]
print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), as: UTF8.self))
