# Bender
[![DUB](https://img.shields.io/dub/l/vibe-d.svg)]() [![CocoaPods](https://img.shields.io/cocoapods/v/Bender.svg)]() [![Carthage](https://img.shields.io/badge/Carthage-1.2.5-brightgreen.svg)]()

Not just yet another JSON mapping framework for Swift, but tool for building rules for JSON structures validating and binding to your data types.

Bender
- focuses on JSON data describing, much like JSON schema does;
- does not require your model classes to inherit from any library roots;
- type-safe;
- supports mandatory/optional fields checking with error throwing;
- does not require exact field naming or even field existence;
- supports classes/structs with all JSON natural field types, nested/recursively nested ones, arrays as class/struct fields or JSON root ones, custom enums, 'stringified' JSON;
- allows you to dump data structures using validation rules written once;
- allows you to write your own validator/dumper in a couple of dozen lines;
- small: ~500 loc in Swift.

### Example
Let's assume we receive in JSON the struct like this:
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
How could we check if we got the proper data? Bender helps us to describe our expectations. Let's start from the single level:
```swift
  let folderRule = ClassRule(Folder())
    .expect("title", StringRule) { $0.name = $1 }
    .expect("size", Int64Rule) { $0.size = $1 }
```
What does it mean? We literally created a _rule_, a schema that describes what we expect in our JSON: a struct with two mandatory fields, one of them is String and named "title", another is Int64 and named "size". But after all we want to _bind_ values that can be extracted from these fields into fields of a corresponding class Folder. 

ClassRule gets ```@autoclosure``` that constructs new Folder object each time we are going to validate corresponding JSON fragment.

In bind closures like ```{ $0.name = $1 }``` we pass Folder object reference as a $0 param and value exctracted for field "name" from JSON as $1. It is up to you what exact method of bindable item to call here. There can be adapters, coders, decoders, transformers etc., not only plain vanilla assignment.

The rule may be declared once but used everywhere we have a new JSON object:
```swift
  let folder = try folderRule.validate(jsonObject) // 'folder' will be of type Folder
```
Wait. What about nested folders? Not a problem. Just add _optional_ field expectation to our rule, and it could be even the same rule:
```swift
  folderRule.optional("folders", ArrayRule(itemRule: folderRule)) { $0.folders = $1 }
```
How does ```validate``` work? It will try to find mandatory fields in JSON, and if found, will try to bind them in accordance with given bind rules. If one of mandatory rules does not find proper field, or field could not be validated itself, the exception will be thrown, and bind will not happen. Then all optional fields will be checked, and if any of them was found but not validated, again, an exception will be thrown.

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

At the same time our Core Data scheme can be traditional one (let's omit some boring boilerplate Core Data code):
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
You can add your own rule to the system. All you need for that is to conform to very simple ```Rule``` protocol:
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
  pod 'Bender', '~> 1.2.5'
```
**Carthage:**
```
github "ptiz/Bender" == 1.2.5
```

**Manual:**

Bender is one-file project. So you can just add ```Bender.swift``` file to your project.
