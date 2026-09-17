///|
pub fn library_name() -> String {
  "LuoYunxin1/moonodata"
}

///|
pub fn odata_version() -> String {
  "4.0"
}

///|
pub fn supported_query_options() -> Array[String] {
  [
    "$filter",
    "$select",
    "$expand",
    "$orderby",
    "$top",
    "$skip",
    "$count",
    "$search",
    "$format",
  ]
}
