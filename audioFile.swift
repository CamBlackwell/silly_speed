import Foundation

struct AudioFile : Identifiable, Codable {
    let id : UUID
    let fileName : String
    let fileURL : URL
    let dateAdded : Date
} 

init (fileName: String, fileURL: URL){
    self.id = UUID()
    self.fileName = fileName
    self.fileURL = fileURL
    self.dateAdded = Date
}