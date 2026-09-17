///|
/// OData 4.0 application errors for URL, JSON, and EDM codecs.
pub(all) enum ODataError {
  Syntax(String)
  TypeMismatch(String)
  Constraint(String)
  NotImplemented(String)
  JsonParse(String)
  Metadata(String)
} derive(Eq, Debug)

///|
pub fn ODataError::message(self : ODataError) -> String {
  match self {
    Syntax(s) => "syntax: " + s
    TypeMismatch(s) => "type: " + s
    Constraint(s) => "constraint: " + s
    NotImplemented(s) => "not-implemented: " + s
    JsonParse(s) => "json: " + s
    Metadata(s) => "metadata: " + s
  }
}

///|
pub fn[T] unwrap_odata(r : Result[T, ODataError]) -> T {
  match r {
    Ok(v) => v
    Err(e) => abort(e.message())
  }
}
