/*
 * Tencent is pleased to support the open source community by making
 * WCDB available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *       https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
import WCDB

class FileTests: XCTestCase {
    static let name = String(describing: FileTests.self)
    static let fileURL = URL(fileURLWithPath: FileTests.name, relativeTo: FileManager.default.temporaryDirectory)

    var database: Database!

    override func setUp() {
        super.setUp()
        database = Database(withFileURL: FileTests.fileURL)
        database.close { 
            XCTAssertNoThrow(try self.database.removeFiles())
        }
    }
    
    override func tearDown() {
        database.close { 
            XCTAssertNoThrow(try self.database.removeFiles())
        }
        super.tearDown()
    }
    
    func testPaths() {
        //Give
        let path = FileTests.fileURL.path
        let expertedPaths = [path, path+"-wal", path+"-shm", path+"-journal", path+"-backup"]
        //Then
        XCTAssertEqual(database.paths.sorted(), expertedPaths.sorted())
    }
    
    func testRemoveFiles() {
        //Give
        let fileManager = FileManager.default

        for path in database.paths {
            if fileManager.fileExists(atPath: path) {
                XCTAssertNoThrow(try fileManager.removeItem(atPath: path))
            }
            XCTAssertNoThrow(fileManager.createFile(atPath: path, contents: nil, attributes: nil)) 
        }
        //When
        database.close { 
            XCTAssertNoThrow(try self.database.removeFiles())
        }
        //Then
        for path in database.paths {
            XCTAssertFalse(fileManager.fileExists(atPath: path))
        }
    }
    
    func testMoveFiles() {
        //Give
        let fileManager = FileManager.default

        let extraFile = URL(fileURLWithPath: "extraFile", relativeTo: fileManager.temporaryDirectory).path
        let paths = database.paths + [extraFile]
        for path in paths {
            XCTAssertNoThrow(fileManager.createFile(atPath: path, contents: nil, attributes: nil)) 
        }
        
        let newDirectory = URL(fileURLWithPath: "newDirectory", relativeTo: fileManager.temporaryDirectory).path
        
        let newPaths = paths.map { (path) -> String in
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            return URL(fileURLWithPath: newDirectory).appendingPathComponent(fileName).path
        }
        
        for path in newPaths {
            if fileManager.fileExists(atPath: path) {
                XCTAssertNoThrow(try fileManager.removeItem(atPath: path))
            }
        }
        
        //When
        XCTAssertNoThrow(try database.moveFiles(toDirectory: newDirectory, withExtraFiles: extraFile))
        //Then
        for path in newPaths {
            XCTAssertTrue(fileManager.fileExists(atPath: path))
        }
        
        //Clear
        XCTAssertNoThrow(try fileManager.removeItem(atPath: newDirectory))
    }
    
    func testGetFilesSize() {
        //Give
        let fileManager = FileManager.default
        let data = "testGetFilesSize".data(using: .ascii)!
        let expectedFilesSize = data.count * database.paths.count
        for path in database.paths {
            if fileManager.fileExists(atPath: path) {
                XCTAssertNoThrow(try fileManager.removeItem(atPath: path))
            }
            XCTAssertNoThrow(fileManager.createFile(atPath: path, contents: data, attributes: nil)) 
        }
        //Then
        database.close { 
            do {
                let filesSize = try self.database.getFilesSize()
                XCTAssertEqual(filesSize, UInt64(expectedFilesSize))
            }catch let error as WCDB.Error {
                XCTFail(error.description)
            }catch {}
        }
    }
}
