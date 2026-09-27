import XCTest
@testable import ContainerUI

final class BackgroundJobTests: XCTestCase {

    func testCleanProgressLine_stripsStepAndTimer() {
        XCTAssertEqual(BackgroundJob.cleanProgressLine("[4/6] Fetching init image 45% (3 of 4 blobs, 30,0/65,9 MB) [4s]"),
                       "Fetching init image 45% (3 of 4 blobs, 30,0/65,9 MB)")
        XCTAssertEqual(BackgroundJob.cleanProgressLine("#5 [2/3] RUN apk add curl"), "#5 [2/3] RUN apk add curl")
    }

    func testPercentage_combinesStepAndStepPercentage() {
        // Step 4 of 6 at 50%: three steps done + half of the fourth.
        XCTAssertEqual(BackgroundJob.percentage(in: "[4/6] Fetching init image 50% (x) [4s]")!, 3.5 / 6, accuracy: 0.0001)
        XCTAssertEqual(BackgroundJob.percentage(in: "[6/6] Starting container [6s]")!, 5.0 / 6, accuracy: 0.0001)
    }

    func testPercentage_plainPercentOrNone() {
        XCTAssertEqual(BackgroundJob.percentage(in: "downloading 25%")!, 0.25, accuracy: 0.0001)
        XCTAssertNil(BackgroundJob.percentage(in: "#3 DONE 0.1s"))
    }
}
