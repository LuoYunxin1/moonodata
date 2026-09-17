///|
pub(all) enum Literal {
  Null
  Bool(Bool)
  Int(Int)
  Float(Double)
  Text(String)
} derive(Eq, Debug)

///|
pub fn Literal::to_url(self : Literal) -> String {
  match self {
    Null => "null"
    Bool(true) => "true"
    Bool(false) => "false"
    Int(n) => n.to_string()
    Float(n) => n.to_string()
    Text(s) => "'" + s.replace(old="'", new="''") + "'"
  }
}
