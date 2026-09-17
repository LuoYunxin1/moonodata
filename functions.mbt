///|
/// Canonical OData 4.0 canonical functions used in $filter.
pub fn known_filter_functions() -> Array[String] {
  [
    "contains",
    "startswith",
    "endswith",
    "length",
    "indexof",
    "substring",
    "tolower",
    "toupper",
    "trim",
    "concat",
    "year",
    "month",
    "day",
    "hour",
    "minute",
    "second",
    "fractionalseconds",
    "totalseconds",
    "date",
    "time",
    "round",
    "floor",
    "ceiling",
    "geo.distance",
    "geo.intersects",
    "geo.length",
  ]
}

///|
pub fn filter_function_arity(name : String) -> Int? {
  match name {
    "contains" | "startswith" | "endswith" | "indexof" | "concat" => Some(2)
    "substring" => Some(3)
    "length" | "tolower" | "toupper" | "trim" | "year" | "month" | "day" | "hour" | "minute" | "second" | "fractionalseconds" | "totalseconds" | "date" | "time" | "round" | "floor" | "ceiling" | "geo.length" =>
      Some(1)
    "geo.distance" | "geo.intersects" => Some(2)
    _ => None
  }
}

///|
fn check_call_arity(expr : Filter) -> Result[Unit, ODataError] {
  match expr {
    Call(name, args) => {
      match filter_function_arity(name) {
        None => Ok(())
        Some(n) =>
          if name == "substring" {
            if args.length() == 2 || args.length() == 3 {
              Ok(())
            } else {
              Err(Constraint("substring expects 2 or 3 arguments"))
            }
          } else if args.length() == n {
            Ok(())
          } else {
            Err(Constraint(name + " arity mismatch"))
          }
      }
    }
    And(l, r) | Or(l, r) | Cmp(_, l, r) => {
      match check_call_arity(l) {
        Err(e) => Err(e)
        Ok(_) => check_call_arity(r)
      }
    }
    Not(x) => check_call_arity(x)
    Literal(_) | Property(_) => Ok(())
  }
}

///|
pub fn is_known_filter_function(name : String) -> Bool {
  match filter_function_arity(name) {
    Some(_) => true
    None => false
  }
}

///|
pub fn describe_filter(expr : Filter) -> String {
  match expr {
    Literal(lit) => "literal:" + lit.to_url()
    Property(parts) => {
      let mut s = "property:"
      let mut i = 0
      while i < parts.length() {
        if i > 0 {
          s = s + "/"
        }
        s = s + parts[i]
        i = i + 1
      }
      s
    }
    Call(name, args) => "call:" + name + "/" + args.length().to_string()
    Cmp(op, _, _) => "cmp:" + op.to_url()
    And(_, _) => "and"
    Or(_, _) => "or"
    Not(_) => "not"
  }
}
