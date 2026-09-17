///|
test "empty query" {
  let q = unwrap_odata(parse_query(""))
  assert_eq(q.to_url(), "")
}

///|
test "filter not trailing" {
  match parse_filter("Name eq 'A' oops") {
    Err(Syntax(_)) => ()
    Ok(_) => abort("expected trailing error")
    Err(e) => abort(e.message())
  }
}
