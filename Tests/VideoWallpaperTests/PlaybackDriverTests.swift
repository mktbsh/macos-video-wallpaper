import Dispatch
import Foundation
import Testing
@testable import VideoWallpaper

@Suite
struct MainActorCompletionRelayTests {

    @Test func run_executes_inline_when_already_on_main_thread() async {
        await MainActor.run {
            var didRun = false

            MainActorCompletionRelay.run {
                didRun = true
            }

            #expect(didRun == true)
        }
    }

    @Test func run_handoffs_background_work_to_main_thread() async {
        let executedOnMainThread = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                MainActorCompletionRelay.run {
                    continuation.resume(returning: Thread.isMainThread)
                }
            }
        }

        #expect(executedOnMainThread == true)
    }
}
