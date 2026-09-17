///|
pub fn validate_query(q : QueryOptions) -> Result[Unit, ODataError] {
  match q.filter {
    Some(f) =>
      match check_call_arity(f) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    None => ()
  }
  match q.top {
    Some(n) =>
      if n < 0 {
        return Err(Constraint("$top must be >= 0"))
      }
    None => ()
  }
  match q.skip {
    Some(n) =>
      if n < 0 {
        return Err(Constraint("$skip must be >= 0"))
      }
    None => ()
  }
  match q.select {
    Some(xs) =>
      if xs.length() == 0 {
        return Err(Constraint("$select must not be empty"))
      }
    None => ()
  }
  Ok(())
}

///|
pub fn validate_request(req : ODataRequest, schema~ : EdmSchema?) -> Result[Unit, ODataError] {
  match validate_query(req.query) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if req.path.segments.length() == 0 {
    return Err(Constraint("resource path is empty"))
  }
  match schema {
    None => Ok(())
    Some(edm) => {
      match req.path.segments[0] {
        EntitySet(name) | Property(name) =>
          match edm.find_set(name) {
            None => Err(Constraint("unknown entity set " + name))
            Some(_) => Ok(())
          }
        Metadata => Ok(())
        Count | Value | Ref | Key(_) => Err(Constraint("path must start with entity set"))
      }
    }
  }
}
