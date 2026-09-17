///|
pub(all) enum KeyPart {
  Positional(Literal)
  Named(String, Literal)
} derive(Eq, Debug)

///|
pub(all) enum PathSeg {
  EntitySet(String)
  Key(Array[KeyPart])
  Property(String)
  Count
  Value
  Ref
  Metadata
} derive(Eq, Debug)

///|
pub(all) struct ResourcePath {
  segments : Array[PathSeg]
} derive(Eq, Debug)

///|
fn parse_key_literal(c : Cursor) -> Result[Literal, ODataError] {
  skip_ws(c)
  let ch = cursor_peek(c)
  if ch == 39 {
    match read_quoted(c, 39) {
      Ok(s) => Ok(Text(s))
      Err(e) => Err(e)
    }
  } else if starts_with_at(c, "true") {
    c.i += 4
    Ok(Bool(true))
  } else if starts_with_at(c, "false") {
    c.i += 5
    Ok(Bool(false))
    } else if starts_with_at(c, "null") {
    c.i += 4
    Ok(Null)
  } else if is_digit(ch) || ch == 45 {
    parse_number_literal(c)
  } else {
    Err(Syntax("expected key literal"))
  }
}

///|
fn parse_number_literal(c : Cursor) -> Result[Literal, ODataError] {
  let start = c.i
  if cursor_peek(c) == 45 {
    cursor_bump(c)
  }
  if !is_digit(cursor_peek(c)) {
    return Err(Syntax("expected number"))
  }
  while is_digit(cursor_peek(c)) {
    cursor_bump(c)
  }
  let mut is_float = false
  if cursor_peek(c) == 46 {
    is_float = true
    cursor_bump(c)
    if !is_digit(cursor_peek(c)) {
      return Err(Syntax("expected fraction digits"))
    }
    while is_digit(cursor_peek(c)) {
      cursor_bump(c)
    }
  }
  let raw = slice_text(c.src, start, c.i)
  if is_float {
    match parse_float_text(raw) {
      Ok(n) => Ok(Float(n))
      Err(e) => Err(e)
    }
  } else {
    match parse_int_text(raw) {
      Ok(n) => Ok(Int(n))
      Err(e) => Err(e)
    }
  }
}

///|
fn parse_key_predicate(c : Cursor) -> Result[Array[KeyPart], ODataError] {
  if cursor_peek(c) != 40 {
    return Err(Syntax("expected '('"))
  }
  cursor_bump(c)
  let parts : Array[KeyPart] = []
  skip_ws(c)
  if cursor_peek(c) == 41 {
    return Err(Syntax("empty key predicate"))
  }
  while true {
    skip_ws(c)
    let save = c.i
    if is_ident_start(cursor_peek(c)) {
      let name = read_ident(c)
      skip_ws(c)
      if cursor_peek(c) == 61 {
        cursor_bump(c)
        match parse_key_literal(c) {
          Ok(lit) => parts.push(Named(name, lit))
          Err(e) => return Err(e)
        }
      } else {
        c.i = save
        match parse_key_literal(c) {
          Ok(lit) => parts.push(Positional(lit))
          Err(e) => return Err(e)
        }
      }
    } else {
      match parse_key_literal(c) {
        Ok(lit) => parts.push(Positional(lit))
        Err(e) => return Err(e)
      }
    }
    skip_ws(c)
    if cursor_peek(c) == 44 {
      cursor_bump(c)
    } else {
      break
    }
  }
  skip_ws(c)
  if cursor_peek(c) != 41 {
    return Err(Syntax("expected ')' after key"))
  }
  cursor_bump(c)
  Ok(parts)
}

///|
pub fn parse_resource_path(text : String) -> Result[ResourcePath, ODataError] {
  let c = cursor_new(text)
  skip_ws(c)
  while cursor_peek(c) == 47 {
    cursor_bump(c)
  }
  let segs : Array[PathSeg] = []
  if cursor_eof(c) {
    return Ok({ segments: segs })
  }
  while !cursor_eof(c) {
    skip_ws(c)
    if cursor_eof(c) {
      break
    }
    if cursor_peek(c) == 36 {
      let name = read_ident(c)
      match name {
        "$count" => segs.push(Count)
        "$value" => segs.push(Value)
        "$ref" => segs.push(Ref)
        "$metadata" => segs.push(Metadata)
        _ => return Err(Syntax("unknown path option " + name))
      }
    } else if is_ident_start(cursor_peek(c)) {
      let name = read_ident(c)
      segs.push(EntitySet(name))
      skip_ws(c)
      if cursor_peek(c) == 40 {
        match parse_key_predicate(c) {
          Ok(parts) => segs.push(Key(parts))
          Err(e) => return Err(e)
        }
      }
    } else if cursor_peek(c) == 47 {
      cursor_bump(c)
      continue
    } else {
      return Err(Syntax("unexpected path character"))
    }
    skip_ws(c)
    if cursor_peek(c) == 47 {
      cursor_bump(c)
      // After a slash, a property is not always EntitySet; treat ident as Property
      // unless it is a system option. The next loop iteration handles it.
      skip_ws(c)
      if is_ident_start(cursor_peek(c)) && cursor_peek(c) != 36 {
        let name = read_ident(c)
        if segs.length() > 0 {
          segs.push(Property(name))
        } else {
          segs.push(EntitySet(name))
        }
        skip_ws(c)
        if cursor_peek(c) == 40 {
          match parse_key_predicate(c) {
            Ok(parts) => segs.push(Key(parts))
            Err(e) => return Err(e)
          }
        }
      }
    } else {
      break
    }
  }
  skip_ws(c)
  if !cursor_eof(c) {
    return Err(Syntax("trailing path content"))
  }
  Ok({ segments: segs })
}

///|
pub fn ResourcePath::to_url(self : ResourcePath) -> String {
  let mut out = ""
  let mut i = 0
  while i < self.segments.length() {
    match self.segments[i] {
      EntitySet(name) => {
        if out.length() > 0 {
          out = out + "/"
        }
        out = out + name
      }
      Property(name) => { out = out + "/" + name }
      Count => { out = out + "/$count" }
      Value => { out = out + "/$value" }
      Ref => { out = out + "/$ref" }
      Metadata => { out = out + "/$metadata" }
      Key(parts) => {
        out = out + "("
        let mut j = 0
        while j < parts.length() {
          if j > 0 {
            out = out + ","
          }
          match parts[j] {
            Positional(lit) => out = out + lit.to_url()
            Named(n, lit) => out = out + n + "=" + lit.to_url()
          }
          j = j + 1
        }
        out = out + ")"
      }
    }
    i = i + 1
  }
  if out.length() == 0 {
    "/"
  } else {
    "/" + out
  }
}
