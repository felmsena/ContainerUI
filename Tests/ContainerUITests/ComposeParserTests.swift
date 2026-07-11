import XCTest
@testable import ContainerUI

final class ComposeParserTests: XCTestCase {

    // MARK: - Happy path

    func testParsesFullService() throws {
        let yaml = """
        services:
          db:
            image: postgres:16
            ports:
              - "5432:5432"
            env:
              - POSTGRES_PASSWORD=secret
            volumes:
              - db-data:/var/lib/postgresql/data
        """
        let group = try ComposeParser.parse(yaml).get()
        XCTAssertEqual(group.services.count, 1)
        let db = group.services[0]
        XCTAssertEqual(db.name, "db")
        XCTAssertEqual(db.image, "postgres:16")
        XCTAssertEqual(db.ports, ["5432:5432"])
        XCTAssertEqual(db.env, ["POSTGRES_PASSWORD=secret"])
        XCTAssertEqual(db.volumes, ["db-data:/var/lib/postgresql/data"])
        XCTAssertEqual(db.dependsOn, [])
    }

    func testParsesMultipleServicesWithDependsOn() throws {
        let yaml = """
        services:
          db:
            image: postgres:16
          web:
            image: myapp:latest
            ports:
              - 8080:80
            depends_on:
              - db
        """
        let group = try ComposeParser.parse(yaml).get()
        XCTAssertEqual(group.services.map(\.name), ["db", "web"])
        XCTAssertEqual(group.services[1].dependsOn, ["db"])
    }

    func testImageOnlyServiceIsValid() throws {
        let yaml = """
        services:
          cache:
            image: redis:7
        """
        let group = try ComposeParser.parse(yaml).get()
        XCTAssertEqual(group.services, [ComposeService(name: "cache", image: "redis:7")])
    }

    func testCommentsAndBlankLinesAreIgnored() throws {
        let yaml = """
        # top-level comment
        services:

          db:
            # a comment before image
            image: postgres:16  # trailing comment
        """
        let group = try ComposeParser.parse(yaml).get()
        XCTAssertEqual(group.services, [ComposeService(name: "db", image: "postgres:16")])
    }

    func testQuotedValuesAreUnquoted() throws {
        let yaml = """
        services:
          web:
            image: "myapp:latest"
            ports:
              - '8080:80'
        """
        let group = try ComposeParser.parse(yaml).get()
        XCTAssertEqual(group.services[0].image, "myapp:latest")
        XCTAssertEqual(group.services[0].ports, ["8080:80"])
    }

    func testHashInsideQuotesIsNotTreatedAsComment() throws {
        let yaml = """
        services:
          web:
            image: myapp:latest
            env:
              - "TOKEN=abc#def"
        """
        let group = try ComposeParser.parse(yaml).get()
        XCTAssertEqual(group.services[0].env, ["TOKEN=abc#def"])
    }

    // MARK: - Errors

    func testEmptyDocumentFails() {
        XCTAssertEqual(ComposeParser.parse("").failureValue, .emptyDocument)
        XCTAssertEqual(ComposeParser.parse("   \n\n").failureValue, .emptyDocument)
    }

    func testMissingServicesKeyFails() {
        let yaml = """
        db:
          image: postgres:16
        """
        XCTAssertEqual(ComposeParser.parse(yaml).failureValue, .missingServicesKey)
    }

    func testUnknownKeyFails() {
        let yaml = """
        services:
          db:
            image: postgres:16
            restart: always
        """
        guard case .failure(.unknownKey(let key, let service, _)) = ComposeParser.parse(yaml) else {
            return XCTFail("expected .unknownKey")
        }
        XCTAssertEqual(key, "restart")
        XCTAssertEqual(service, "db")
    }

    func testMissingImageFails() {
        let yaml = """
        services:
          db:
            ports:
              - 5432:5432
        """
        XCTAssertEqual(ComposeParser.parse(yaml).failureValue, .missingImage(service: "db"))
    }

    func testDuplicateServiceFails() {
        let yaml = """
        services:
          db:
            image: postgres:16
          db:
            image: mysql:8
        """
        guard case .failure(.duplicateService(let name, _)) = ComposeParser.parse(yaml) else {
            return XCTFail("expected .duplicateService")
        }
        XCTAssertEqual(name, "db")
    }

    func testUnknownDependencyFails() {
        let yaml = """
        services:
          web:
            image: myapp:latest
            depends_on:
              - db
        """
        XCTAssertEqual(ComposeParser.parse(yaml).failureValue, .unknownDependency("db", service: "web"))
    }

    func testWrongServiceIndentFails() {
        let yaml = """
        services:
         db:
            image: postgres:16
        """
        guard case .failure(.badIndentation) = ComposeParser.parse(yaml) else {
            return XCTFail("expected .badIndentation")
        }
    }

    func testMalformedListItemFails() {
        let yaml = """
        services:
          db:
            image: postgres:16
            ports:
              -
        """
        guard case .failure(.malformedListItem) = ComposeParser.parse(yaml) else {
            return XCTFail("expected .malformedListItem")
        }
    }

    func testRejectsUnknownTopLevelKeyAsServiceHeader() {
        // A malformed service header (no trailing colon) surfaces immediately
        // rather than being silently ignored.
        let yaml = """
        services:
          db
        """
        guard case .failure(.invalidServiceHeader) = ComposeParser.parse(yaml) else {
            return XCTFail("expected .invalidServiceHeader")
        }
    }

    // MARK: - Topological order

    func testTopologicalOrder_linearChain() throws {
        let group = ComposeGroup(services: [
            ComposeService(name: "web", image: "web:1", dependsOn: ["api"]),
            ComposeService(name: "api", image: "api:1", dependsOn: ["db"]),
            ComposeService(name: "db", image: "db:1"),
        ])
        let ordered = try ComposeParser.topologicalOrder(group).get()
        XCTAssertEqual(ordered.map(\.name), ["db", "api", "web"])
    }

    func testTopologicalOrder_independentServicesKeepDeclarationOrder() throws {
        let group = ComposeGroup(services: [
            ComposeService(name: "b", image: "b:1"),
            ComposeService(name: "a", image: "a:1"),
        ])
        let ordered = try ComposeParser.topologicalOrder(group).get()
        XCTAssertEqual(ordered.map(\.name), ["b", "a"])
    }

    func testTopologicalOrder_detectsDirectCycle() {
        let group = ComposeGroup(services: [
            ComposeService(name: "a", image: "a:1", dependsOn: ["b"]),
            ComposeService(name: "b", image: "b:1", dependsOn: ["a"]),
        ])
        guard case .failure(.dependencyCycle(let names)) = ComposeParser.topologicalOrder(group) else {
            return XCTFail("expected .dependencyCycle")
        }
        XCTAssertEqual(Set(names), ["a", "b"])
    }

    func testTopologicalOrder_detectsSelfCycle() {
        let group = ComposeGroup(services: [
            ComposeService(name: "a", image: "a:1", dependsOn: ["a"]),
        ])
        guard case .failure(.dependencyCycle(let names)) = ComposeParser.topologicalOrder(group) else {
            return XCTFail("expected .dependencyCycle")
        }
        XCTAssertEqual(names, ["a"])
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
