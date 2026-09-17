///|
pub(all) enum CmpOp {
  Eq
  Ne
  Gt
  Ge
  Lt
  Le
} derive(Eq, Debug)

///|
pub fn CmpOp::to_url(self : CmpOp) -> String {
  match self {
    Eq => "eq"
    Ne => "ne"
    Gt => "gt"
    Ge => "ge"
    Lt => "lt"
    Le => "le"
  }
}

///|
pub(all) enum Filter {
  Literal(Literal)
  Property(Array[String])
  Call(String, Array[Filter])
  Cmp(CmpOp, Filter, Filter)
  And(Filter, Filter)
  Or(Filter, Filter)
  Not(Filter)
} derive(Eq, Debug)

///|
pub fn Filter::to_url(self : Filter) -> String {
  match self {
    Literal(lit) => lit.to_url()
    Property(parts) => {
      let mut s = ""
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
    Call(name, args) => {
      let mut s = name + "("
      let mut i = 0
      while i < args.length() {
        if i > 0 {
          s = s + ","
        }
        s = s + args[i].to_url()
        i = i + 1
      }
      s + ")"
    }
    Cmp(op, l, r) => l.to_url() + " " + op.to_url() + " " + r.to_url()
    And(l, r) => "(" + l.to_url() + " and " + r.to_url() + ")"
    Or(l, r) => "(" + l.to_url() + " or " + r.to_url() + ")"
    Not(x) => "not (" + x.to_url() + ")"
  }
}

///|
fn parse_filter_literal(c : Cursor) -> Result[Filter, ODataError] {
  skip_ws(c)
  if cursor_peek(c) == 39 {
    match read_quoted(c, 39) {
      Ok(s) => Ok(Literal(Text(s)))
      Err(e) => Err(e)
    }
  } else if starts_with_at(c, "true") {
    c.i += 4
    Ok(Literal(Bool(true)))
  } else if starts_with_at(c, "false") {
    c.i += 5
    Ok(Literal(Bool(false)))
  } else if starts_with_at(c, "null") {
    c.i += 4
    Ok(Literal(Null))
  } else if is_digit(cursor_peek(c)) || (cursor_peek(c) == 45 && is_digit(cursor_peek_at(c, 1))) {
    match parse_number_literal(c) {
      Ok(lit) => Ok(Literal(lit))
      Err(e) => Err(e)
    }
  } else {
    Err(Syntax("expected literal"))
  }
}

///|
fn parse_property_or_call(c : Cursor) -> Result[Filter, ODataError] {
  skip_ws(c)
  if !is_ident_start(cursor_peek(c)) {
    return Err(Syntax("expected identifier"))
  }
  let name = read_ident(c)
  skip_ws(c)
  if cursor_peek(c) == 40 {
    cursor_bump(c)
    let args : Array[Filter] = []
    skip_ws(c)
    if cursor_peek(c) != 41 {
      while true {
        match parse_or(c) {
          Ok(arg) => args.push(arg)
          Err(e) => return Err(e)
        }
        skip_ws(c)
        if cursor_peek(c) == 44 {
          cursor_bump(c)
        } else {
          break
        }
      }
    }
    skip_ws(c)
    if cursor_peek(c) != 41 {
      return Err(Syntax("expected ')' in function " + name))
    }
    cursor_bump(c)
    Ok(Call(name, args))
  } else {
    let parts : Array[String] = [name]
    while cursor_peek(c) == 47 {
      cursor_bump(c)
      if !is_ident_start(cursor_peek(c)) {
        return Err(Syntax("expected property path"))
      }
      parts.push(read_ident(c))
    }
    Ok(Property(parts))
  }
}

///|
fn parse_primary(c : Cursor) -> Result[Filter, ODataError] {
  skip_ws(c)
  if cursor_peek(c) == 40 {
    cursor_bump(c)
    match parse_or(c) {
      Ok(inner) => {
        skip_ws(c)
        if cursor_peek(c) != 41 {
          return Err(Syntax("expected ')'"))
        }
        cursor_bump(c)
        Ok(inner)
      }
      Err(e) => Err(e)
    }
  } else if starts_with_at(c, "not") && !is_ident_part(cursor_peek_at(c, 3)) {
    c.i += 3
    match parse_primary(c) {
      Ok(x) => Ok(Not(x))
      Err(e) => Err(e)
    }
  } else {
    let save = c.i
    match parse_filter_literal(c) {
      Ok(v) => Ok(v)
      Err(_) => {
        c.i = save
        parse_property_or_call(c)
      }
    }
  }
}

///|
fn parse_cmp(c : Cursor) -> Result[Filter, ODataError] {
  match parse_primary(c) {
    Err(e) => Err(e)
    Ok(left) => {
      skip_ws(c)
      let op = if starts_with_at(c, "eq") && !is_ident_part(cursor_peek_at(c, 2)) {
        c.i += 2
        Some(Eq)
      } else if starts_with_at(c, "ne") && !is_ident_part(cursor_peek_at(c, 2)) {
        c.i += 2
        Some(Ne)
      } else if starts_with_at(c, "ge") && !is_ident_part(cursor_peek_at(c, 2)) {
        c.i += 2
        Some(Ge)
      } else if starts_with_at(c, "gt") && !is_ident_part(cursor_peek_at(c, 2)) {
        c.i += 2
        Some(Gt)
      } else if starts_with_at(c, "le") && !is_ident_part(cursor_peek_at(c, 2)) {
        c.i += 2
        Some(Le)
      } else if starts_with_at(c, "lt") && !is_ident_part(cursor_peek_at(c, 2)) {
        c.i += 2
        Some(Lt)
      } else {
        None
      }
      match op {
        None => Ok(left)
        Some(kind) =>
          match parse_primary(c) {
            Ok(right) => Ok(Cmp(kind, left, right))
            Err(e) => Err(e)
          }
      }
    }
  }
}

///|
fn parse_and(c : Cursor) -> Result[Filter, ODataError] {
  match parse_cmp(c) {
    Err(e) => Err(e)
    Ok(left0) => {
      let mut left = left0
      while true {
        skip_ws(c)
        if starts_with_at(c, "and") && !is_ident_part(cursor_peek_at(c, 3)) {
          c.i += 3
          match parse_cmp(c) {
            Ok(right) => left = And(left, right)
            Err(e) => return Err(e)
          }
        } else {
          break
        }
      }
      Ok(left)
    }
  }
}

///|
fn parse_or(c : Cursor) -> Result[Filter, ODataError] {
  match parse_and(c) {
    Err(e) => Err(e)
    Ok(left0) => {
      let mut left = left0
      while true {
        skip_ws(c)
        if starts_with_at(c, "or") && !is_ident_part(cursor_peek_at(c, 2)) {
          c.i += 2
          match parse_and(c) {
            Ok(right) => left = Or(left, right)
            Err(e) => return Err(e)
          }
        } else {
          break
        }
      }
      Ok(left)
    }
  }
}

///|
pub fn parse_filter(text : String) -> Result[Filter, ODataError] {
  let c = cursor_new(text)
  match parse_or(c) {
    Err(e) => Err(e)
    Ok(expr) => {
      skip_ws(c)
      if cursor_eof(c) {
        Ok(expr)
      } else {
        Err(Syntax("trailing filter content"))
      }
    }
  }
}
