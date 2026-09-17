///|
test "library identity" {
  assert_eq(library_name(), "LuoYunxin1/moonodata")
  assert_eq(odata_version(), "4.0")
  assert_eq(supported_query_options().length(), 9)
}

///|
test "parse products filter select" {
  let req = unwrap_odata(
    parse_url(
      "/Products?$filter=Name eq 'Bread' and Price gt 2&$select=Name,Price&$top=5",
    ),
  )
  match validate_request(req, schema=None) {
    Ok(_) => ()
    Err(e) => abort(e.message())
  }
  match req.query.filter {
    Some(And(_, _)) => ()
    Some(other) => abort("expected and-filter, got " + other.to_url())
    None => abort("missing filter")
  }
  match req.query.select {
    Some(xs) => {
      assert_eq(xs.length(), 2)
      assert_eq(xs[0], "Name")
      assert_eq(xs[1], "Price")
    }
    None => abort("missing select")
  }
  match req.query.top {
    Some(n) => assert_eq(n, 5)
    None => abort("missing top")
  }
}

///|
test "encode keyed expand" {
  let req = unwrap_odata(
    parse_url("/Orders(42)/Customer?$expand=Address&$orderby=Name desc"),
  )
  let url = encode_url(req)
  assert_true(url.contains("/Orders(42)/Customer"))
  assert_true(url.contains("$expand=Address"))
  assert_true(url.contains("$orderby=Name desc"))
}

///|
test "json entity set omits nothing for context" {
  let doc = unwrap_odata(
    parse_payload(
      "{\"@odata.context\":\"https://example.com/$metadata#Products\",\"@odata.count\":2,\"value\":[{\"ID\":1,\"Name\":\"Bread\"},{\"ID\":2,\"Name\":\"Milk\"}]}",
    ),
  )
  match doc {
    EntitySet(ctx, ents, Some(2)) => {
      assert_true(ctx.contains("Products"))
      assert_eq(ents.length(), 2)
      assert_eq(ents[0].properties.get("Name"), Some(Json::string("Bread")))
    }
    _ => abort("expected entity set")
  }
  let json = encode_payload(doc)
  let text = json.stringify()
  assert_true(text.contains("@odata.context"))
  assert_true(text.contains("\"2\"") || text.contains(":2"))
}

///|
test "reject negative top" {
  let req = unwrap_odata(parse_url("/Products?$top=-1"))
  match validate_request(req, schema=None) {
    Err(Constraint(_)) => ()
    Ok(_) => abort("expected constraint")
    Err(e) => abort(e.message())
  }
}

///|
test "metadata entity types" {
  let xml = "<edmx:Edmx><Schema Namespace=\"ODataDemo\"><EntityType Name=\"Product\"><Key><PropertyRef Name=\"ID\"/></Key><Property Name=\"ID\" Type=\"Edm.Int32\" Nullable=\"false\"/><Property Name=\"Name\" Type=\"Edm.String\"/></EntityType><EntitySet Name=\"Products\" EntityType=\"ODataDemo.Product\"/></Schema></edmx:Edmx>"
  let schema = unwrap_odata(parse_metadata(xml))
  assert_eq(schema.ns_, "ODataDemo")
  match schema.find_set("Products") {
    Some(s) => assert_eq(s.type_, "ODataDemo.Product")
    None => abort("missing Products")
  }
  match schema.find_type("Product") {
    Some(t) => {
      assert_eq(t.key.length(), 1)
      assert_eq(t.properties.length(), 2)
    }
    None => abort("missing Product type")
  }
}

///|
test "unknown query option" {
  match parse_url("/Products?$bogus=1") {
    Err(Syntax(_)) => ()
    Ok(_) => abort("expected syntax error")
    Err(e) => abort(e.message())
  }
}

///|
test "contains function roundtrip" {
  let f = unwrap_odata(parse_filter("contains(Name,'br')"))
  assert_eq(f.to_url(), "contains(Name,'br')")
}

///|
test "substring arity" {
  match parse_filter("substring(Name,1,2)") {
    Ok(f) =>
      match validate_query({ filter: Some(f), select: None, expand: None, orderby: None, top: None, skip: None, count: None, search: None, format_: None, }) {
        Ok(_) => ()
        Err(e) => abort(e.message())
      }
    Err(e) => abort(e.message())
  }
}
