///|
pub(all) struct ODataRequest {
  service_root : String
  path : ResourcePath
  query : QueryOptions
} derive(Eq, Debug)

///|
pub fn parse_url(text : String) -> Result[ODataRequest, ODataError] {
  let qat = match find_at(text, "?", 0) {
    Some(i) => i
    None => text.length()
  }
  let path_and_root = slice_text(text, 0, qat)
  let query_text = if qat < text.length() {
    slice_text(text, qat, text.length())
  } else {
    ""
  }
  match parse_resource_path(strip_service_root(path_and_root)) {
    Err(e) => Err(e)
    Ok(path) =>
      match parse_query(query_text) {
        Ok(query) =>
          Ok({ service_root: service_root_of(path_and_root), path, query, })
        Err(e) => Err(e)
      }
  }
}

///|
fn strip_service_root(text : String) -> String {
  match find_at(text, "://", 0) {
    None => text
    Some(s) => {
      let after = s + 3
      match find_at(text, "/", after) {
        None => "/"
        Some(slash) => slice_text(text, slash, text.length())
      }
    }
  }
}

///|
fn service_root_of(text : String) -> String {
  match find_at(text, "://", 0) {
    None => ""
    Some(s) => {
      let after = s + 3
      match find_at(text, "/", after) {
        None => text
        Some(slash) => slice_text(text, 0, slash)
      }
    }
  }
}

///|
pub fn encode_url(req : ODataRequest) -> String {
  req.service_root + req.path.to_url() + req.query.to_url()
}

///|
pub fn parse_url_relative(path_and_query : String) -> Result[ODataRequest, ODataError] {
  parse_url(path_and_query)
}
