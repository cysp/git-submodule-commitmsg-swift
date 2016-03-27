//  Copyright © 2016 Scott Talbot. All rights reserved.

import Foundation
import Git2


private extension Oid {
    var sevenCharacterPrefix: String {
        get {
            var oidString = description
            if oidString.characters.count > 7 {
                oidString = String(oidString.characters.prefix(7))
            }
            return oidString
        }
    }
}

func trim(string: String?) -> String? {
    return string?.trimmingCharacters(in: NSCharacterSet.whitespaceAndNewline())
}


do {
    let r = try Repository.discover(path: ".")

    let rWorkdir = r.workdir!

    let submoduleUpdateMessages = r.submodules.flatMap { (submodule: Submodule) -> (String, String, [String])? in
        guard let submoduleIndexId = submodule.indexId else {
            return nil
        }
        guard let submoduleWorkdirId = submodule.workdirId else {
            return nil
        }
        if submoduleIndexId == submoduleWorkdirId {
            return nil
        }

        var addedCommits: [(Oid, Commit?)] = []
        var droppedCommits: [(Oid, Commit?)] = []
        do {
            let r = try Repository.open(path: rWorkdir + submodule.path)
            do {
                let rw = try r.revwalk()

                do {
                    rw.sorting = [.Topological]
                    try rw.hide(oid: submoduleIndexId)
                    try rw.push(oid: submoduleWorkdirId)

                    let a: [(Oid, Commit?)] = rw.map({ ($0, r.lookupCommit(oid: $0)) })
                    addedCommits.append(contentsOf: a)
                } catch {
//                    print("err: \(error)")
                }

                do {
                    rw.sorting = [.Topological]
                    try rw.hide(oid: submoduleWorkdirId)
                    try rw.push(oid: submoduleIndexId)

                    let d: [(Oid, Commit?)] = rw.map({ ($0, r.lookupCommit(oid: $0)) })
                    droppedCommits.append(contentsOf: d)
                } catch {
//                    print("err: \(error)")
                }
            } catch {
                print("err: \(error)")
            }
        } catch {
            print("err opening submodule: \(error)")
        }

        let submoduleUpdateRangeIndicator: String
        if droppedCommits.isEmpty {
            submoduleUpdateRangeIndicator = ".."
        } else {
            submoduleUpdateRangeIndicator = "..."
        }

        let change = "\(submoduleIndexId.sevenCharacterPrefix)\(submoduleUpdateRangeIndicator)\(submoduleWorkdirId.sevenCharacterPrefix)"

        var body: [String] = []
        for (oid, commit) in addedCommits {
            body.append("+\(oid.sevenCharacterPrefix) \(trim(commit?.summary) ?? "")")
        }
        for (oid, commit) in droppedCommits {
            body.append("-\(oid.sevenCharacterPrefix) \(trim(commit?.summary) ?? "")")
        }

        return (submodule.name, change, body)
    }

    if !submoduleUpdateMessages.isEmpty {
        let subject = "Update " + submoduleUpdateMessages.map({ (submoduleName, change, _) in
            return "\(submoduleName): (\(change))"
        }).joined(separator: ", ")
        let body = submoduleUpdateMessages.flatMap({ (submoduleName, _, body) -> String? in
            if body.count <= 0 {
                return nil
            }
            return ([
                "\(submoduleName):",
            ] + body).joined(separator: "\n")
        }).joined(separator: "\n\n")

        print(subject)
        print("")
        print(body)
    }
} catch {
    print(error)
}
