///|
pub(all) enum EdmType {
  Binary
  Boolean
  Byte
  Date
  DateTimeOffset
  Decimal
  Double
  Duration
  Guid
  Int16
  Int32
  Int64
  SByte
  Single
  Stream
  String
  TimeOfDay
  Complex(String)
  Entity(String)
  Collection(EdmType)
} derive(Eq, Debug)

///|
pub fn EdmType::from_wire(name : String) -> EdmType {
  match name {
    "Edm.Binary" => Binary
    "Edm.Boolean" => Boolean
    "Edm.Byte" => Byte
    "Edm.Date" => Date
    "Edm.DateTimeOffset" => DateTimeOffset
    "Edm.Decimal" => Decimal
    "Edm.Double" => Double
    "Edm.Duration" => Duration
    "Edm.Guid" => Guid
    "Edm.Int16" => Int16
    "Edm.Int32" => Int32
    "Edm.Int64" => Int64
    "Edm.SByte" => SByte
    "Edm.Single" => Single
    "Edm.Stream" => Stream
    "Edm.String" => String
    "Edm.TimeOfDay" => TimeOfDay
    _ => {
      if name.has_prefix("Collection(") && name.has_suffix(")") {
        let inner = slice_text(name, 11, name.length() - 1)
        Collection(EdmType::from_wire(inner))
      } else {
        Entity(name)
      }
    }
  }
}

///|
pub fn EdmType::to_wire(self : EdmType) -> String {
  match self {
    Binary => "Edm.Binary"
    Boolean => "Edm.Boolean"
    Byte => "Edm.Byte"
    Date => "Edm.Date"
    DateTimeOffset => "Edm.DateTimeOffset"
    Decimal => "Edm.Decimal"
    Double => "Edm.Double"
    Duration => "Edm.Duration"
    Guid => "Edm.Guid"
    Int16 => "Edm.Int16"
    Int32 => "Edm.Int32"
    Int64 => "Edm.Int64"
    SByte => "Edm.SByte"
    Single => "Edm.Single"
    Stream => "Edm.Stream"
    String => "Edm.String"
    TimeOfDay => "Edm.TimeOfDay"
    Complex(s) => s
    Entity(s) => s
    Collection(inner) => "Collection(" + inner.to_wire() + ")"
  }
}

///|
pub(all) struct EdmProperty {
  name : String
  type_ : EdmType
  nullable : Bool
} derive(Eq, Debug)

///|
pub(all) struct EntityType {
  name : String
  key : Array[String]
  properties : Array[EdmProperty]
} derive(Eq, Debug)

///|
pub(all) struct EntitySet {
  name : String
  type_ : String
} derive(Eq, Debug)

///|
pub(all) struct EdmSchema {
  ns_ : String
  entity_types : Array[EntityType]
  entity_sets : Array[EntitySet]
} derive(Eq, Debug)

///|
pub fn EdmSchema::find_set(self : EdmSchema, name : String) -> EntitySet? {
  let mut i = 0
  while i < self.entity_sets.length() {
    if self.entity_sets[i].name == name {
      return Some(self.entity_sets[i])
    }
    i = i + 1
  }
  None
}

///|
pub fn EdmSchema::find_type(self : EdmSchema, name : String) -> EntityType? {
  let mut i = 0
  while i < self.entity_types.length() {
    if self.entity_types[i].name == name {
      return Some(self.entity_types[i])
    }
    i = i + 1
  }
  None
}
