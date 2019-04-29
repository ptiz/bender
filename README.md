# Bender
[![DUB](https://img.shields.io/dub/l/vibe-d.svg)]() [![CocoaPods](https://img.shields.io/cocoapods/v/Bender.svg)]() [![Carthage](https://img.shields.io/badge/Carthage-1.6.1-brightgreen.svg)]()

A declarative JSON mapping library which does not pollute your models with ridiculous initializers and stuff. Describes JSON for your classes, does not dress your classes for JSON.

Bender
- focuses on JSON data describing, much like JSON schema does;
- does not make your models depend on the library;
- supports mandatory/optional fields checking with error throwing;
- supports classes, structs with all JSON natural field types, recursively nested ones, arrays as fields or JSON root ones, custom enums, etc;
- supports JSON paths;
- dumps classes back to JSON using same validation rules;
- allows you to write your own validator/dumper in a couple of dozen lines;
- small: ~600 loc in Swift;
- really fast (see performance tests included)!

### Example
Let's assume we received a JSON struct like this:
```json
{
  "title": "root",
  "size": 128,
  "folders": [
      {
        "title": "home",
        "size": 256
      }
    ]
}
```
Here we have recursively nested structs of the same type. And we would like to map the data to the Folder class we have:
```swift
  class Folder {
    var name: String!
    var size: Int64!
    var folders: [Folder]?
  }
```
How could we check if we got the proper data? Bender helps us to describe our expectations. Let's start from an expression as simple as this:
```swift
  let folderRule = ClassRule(Folder())
    .expect("title", StringRule) { $0.name = $1 }
    .expect("size", Int64Rule) { $0.size = $1 }
```
What does it mean? We literally created a _rule_, a schema that describes what we expect in our JSON: a struct (_ClassRule_) with two mandatory fields, one of them is String and named "title" (_StringRule_), another is Int64 and named "size" (_Int64Rule_). But after all we would like to _bind_ values that can be extracted from these fields into fields of a corresponding class Folder.

ClassRule gets ```@autoclosure``` that constructs new Folder object each time we have validated corresponding JSON fragment. It is guaranteed that the binding object will not be created if the validation fails.

In bind closures like ```{ $0.name = $1 }``` we pass Folder object reference as a $0 param and value exctracted for field "name" from JSON as $1. It is up to you what exact method of bindable item to call here. There can be adapters, coders, decoders, transformers etc., not only plain vanilla assignment.

The rule may be declared once but used everywhere we have a new JSON object:
```swift
  let folder = try folderRule.validate(jsonObject) // the resulting 'folder' will be of type Folder
```
Wait. What about nested folders? Not a problem. Just add another field expectation to our rule: _optional_ array. The element in this array can be checked with the same rule we are declaring, recursively:
```swift
  folderRule.optional("folders", ArrayRule(itemRule: folderRule)) { $0.folders = $1 }
```
How does ```validate``` work? It will try to find mandatory fields in JSON and, if succeeded, bind them in accordance with the given bind rules. If one of mandatory rules does not find proper field, or field could not be validated itself, the exception will be thrown, and bind will not happen. Then all optional fields will be checked, and if any of them was found but not validated, again, an exception will be thrown.

And for sure we can dump the Folder class to JSON object using the same rule. All we should do is to add corresponding data accessors:
```swift
  let folderRule = ClassRule(Folder())
    .expect("title", StringRule, { $0.name = $1 }) { $0.name }
    .expect("size", Int64Rule, { $0.size = $1 }) { $0.size }
    
  folderRule    
    .optional("folders", ArrayRule(itemRule: folderRule), { $0.folders = $1 }) { $0.folders }
```
Now we can use the rule for serializing a Folder class:
```swift
  let jsonObject = try folderRule.dump(folder)
```
### Rule list
Basic rules:
- IntRule, Int8Rule, Int16Rule, Int32Rule, Int64Rule (and corresponding UInt... family)
- DoubleRule
- FloatRule
- BoolRule
- StringRule

Compound rules:
- ClassRule - bind class
- StructRule - bind struct
- EnumRule - bind enum to any value set

Rules with nested rules:
- ArrayRule - bind array of ony other type, validated by item rule
- StringifiedJSONRule - bind any rule from JSON encoded into UTF-8 string

### Error handling
Bender throws RuleError enum in case of validating or dumping errors, which stores optional information about a cause of error. 

Let's assume we have erroneous JSON, in which one int value turns out to be a string:
```json
{
  "title": "root",
  "size": 128,
  "folders": [
    {
      "title": "home",
      "size": "256 Error!"
    }
  ]
}
```
Validation throws the RuleError, and you can get the ```error.description```:
```
Unable to validate optional field "folders" for Folder.
Unable to validate array of Folder: item #0 could not be validated.
Unable to validate mandatory field "size" for Folder.
Value of unexpected type found: "256 Error!". Expected Int64.
```

For sure, in some situations we should allow the world to be imperfect. Say, we found one black sheep in an array. Should we fail the validation of the whole array because one small item is erroneous? Sometimes no. Just declare the 'invalidItemHandler' closure:
```swift
let someArrayRule = ArrayRule(itemRule: someRule) {
    print("Error: \($0)")
    // If you still want to throw an error here, you can. Just do it:
    // throw TheError("I am sure this is an unrecoverable error: \($0)")
  }
```
If your 'invalidItemHandler' still throws, the whole array validation will fail in case of item validation error.

### Structs support
Swift structs also supported as bindable items. For example, if our ```Folder``` is struct, not class, we still can bind it, using almost the same ```StructRule```:
```swift
  let folderRule = StructRule(ref(Folder(name: "", size: 0)))
    .expect("title", StringRule, { $0.value.name = $1 }) { $0.name }
    .expect("size", Int64Rule, { $0.value.size = $1 }) { $0.size }
    
  folderRule    
    .optional("folders", ArrayRule(itemRule: folderRule), { $0.value.folders = $1 }) { $0.folders }
```
Have you noticed additional ```ref```? It is boxing object that allows us to pass the struct copied by value as reference through the rule set during validation. Also in our bind closures we should unbox it by calling ```$0.value``` which returns mutable Folder struct.

You can even bind JSON structs into tuples! Use for that the StructRule as well:
```swift
  let folderRule = StructRule(ref(("", 0)))
    .expect("title", StringRule, { $0.value.0 = $1 }) { $0.0 }
    .expect("size", Int64Rule, { $0.value.1 = $1 }) { $0.1 }
  
  let newJson = try folderRule.dump(("home dir", 512))
  let tuple = try folderRule.validate(json) // 'tuple' will be of type (String, Int64)
```

### JSON path
Sometimes you do not need to bind any intermediate JSON dictionaries. For example, you want to extract only 'user' struct from JSON like this:
```json
{
    "message": {
        "payload": {
            "createdBy": {
                "user": {
                    "id": "123456",
                    "login": "johndoe@mail.com"
                }
            }
        }
    }
}
```
You do not need to create redundant classes for all that intermediate stuff. Just use magic operator "/" to construct the path needed:
```swift
  let rule = ClassRule(User())
    .expect("message"/"payload"/"createdBy"/"user"/"id", StringRule) { $0.id = $1 }
    .expect("message"/"payload"/"createdBy"/"user"/"login", StringRule) { $0.name = $1 }
```

### Core Data
Your managed objects can be easily mapped as well. Let's imagine beloved Employee/Department scheme, but a bit more complicated than usual: Employee and Departments are linked by weak identifier, department name.

So here goes Employee...
```json
{
  "name": "John Doe",
  "departmentName": "Marketing"
}
```
... and Department
```json
{
  "name": "Marketing"
}
```

At the same time our Core Data scheme can be the traditional one (let's omit some boring boilerplate Core Data code):
```swift
class Employee: NSManagedObject {
  @NSManaged var name: String
  @NSManaged var department: Department?
}

class Department: NSManagedObject {
  @NSManaged var name: String
  @NSManaged var employees: NSSet
}

func createEmployee(context: NSManagedObjectContext) -> Employee {
  /// ... All that 'NSEntityDescription' and 'NSManagedObject' stuff
}

func createDepartment(context: NSManagedObjectContext) -> Department {
  /// ... All that 'NSEntityDescription' and 'NSManagedObject' stuff
}
```

It is time to create corresponding rules. But the object factories depend on runtime context. So we can wrap our rules creation code with simple functions:
```swift
func departmentByName(context: NSManagedObjectContext, name: String) -> Department? {
  /// ... Searches for department by its name
}

func employeeRule(context: NSManagedObjectContext) -> ClassRule<Employee> {
  return ClassRule(createEmployee(context))
    .expect("name", StringRule) { $0.name = $1 }
    .optional("departmentName", StringRule) { 
      if let dept = departmentByName(context, name: $1) {
        $0.department = dept
        dept.mutableSetValueForKey("employees").addObject($0)
      }
    }
}

func departmentRule(context: NSManagedObjectContext) -> ClassRule<Department> {
  return ClassRule(createDepartment(context))
    .expect("name", StringRule) { $0.name = $1 }
}
```
And now the validation is trivial:
```swift
  try departmentRule(context).validate(deptJson) // here we have Department with name "Marketing" created
  try employeeRule(context).validate(employeeJson) // here we have Employee mapped to corresponding Department
```

### Extensibility
You can add your own rule to the system. All you need is to conform to very simple ```Rule``` protocol:
```swift
public protocol Rule {
    typealias V
    func validate(jsonValue: AnyObject) throws -> V
    func dump(value: V) throws -> AnyObject
}
```

### Installation
**CocoaPods:**
```
  pod 'Bender', '~> 1.6.1'
```
**Carthage:**
```
github "ptiz/Bender" == 1.6.1
```

