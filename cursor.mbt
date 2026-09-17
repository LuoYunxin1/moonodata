///|
priv struct Cursor {
  src : String
  mut i : Int
}

///|
fn cursor_new(src : String) -> Cursor {
  { src, i: 0 }
}

///|
fn cursor_eof(c : Cursor) -> Bool {
  c.i >= c.src.length()
}

///|
fn cursor_peek(c : Cursor) -> Int {
  if cursor_eof(c) {
    -1
  } else {
    c.src[c.i].to_int()
  }
}

///|
fn cursor_peek_at(c : Cursor, n : Int) -> Int {
  let j = c.i + n
  if j >= c.src.length() {
    -1
  } else {
    c.src[j].to_int()
  }
}

///|
fn cursor_bump(c : Cursor) -> Unit {
  if !cursor_eof(c) {
    c.i += 1
  }
}

///|
fn slice_text(s : String, start : Int, end : Int) -> String {
  s[start:end].to_owned()
}

///|
fn find_at(s : String, needle : String, from : Int) -> Int? {
  let n = needle.length()
  if n == 0 {
    return Some(from)
  }
  let mut i = from
  while i + n <= s.length() {
    if slice_text(s, i, i + n) == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn map_from_pairs(pairs : Array[(String, Json)]) -> Map[String, Json] {
  let m : Map[String, Json] = Map([])
  let mut i = 0
  while i < pairs.length() {
    let (k, v) = pairs[i]
    m[k] = v
    i = i + 1
  }
  m
}

///|
fn is_ws(ch : Int) -> Bool {
  ch == 32 || ch == 9 || ch == 10 || ch == 13
}

///|
fn is_alpha(ch : Int) -> Bool {
  (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122)
}

///|
fn is_digit(ch : Int) -> Bool {
  ch >= 48 && ch <= 57
}

///|
fn is_ident_start(ch : Int) -> Bool {
  is_alpha(ch) || ch == 95 || ch == 36
}

///|
fn is_ident_part(ch : Int) -> Bool {
  is_ident_start(ch) || is_digit(ch)
}

///|
fn skip_ws(c : Cursor) -> Unit {
  while is_ws(cursor_peek(c)) {
    cursor_bump(c)
  }
}

///|
fn read_ident(c : Cursor) -> String {
  let start = c.i
  if is_ident_start(cursor_peek(c)) {
    cursor_bump(c)
    while is_ident_part(cursor_peek(c)) {
      cursor_bump(c)
    }
  }
  slice_text(c.src, start, c.i)
}

///|
fn read_quoted(c : Cursor, quote : Int) -> Result[String, ODataError] {
  if cursor_peek(c) != quote {
    return Err(Syntax("expected quoted string"))
  }
  cursor_bump(c)
  let mut out = ""
  while !cursor_eof(c) {
    let ch = cursor_peek(c)
    if ch == quote {
      if cursor_peek_at(c, 1) == quote {
        out = out + "'"
        cursor_bump(c)
        cursor_bump(c)
      } else {
        cursor_bump(c)
        return Ok(out)
      }
    } else {
      out = out + slice_text(c.src, c.i, c.i + 1)
      cursor_bump(c)
    }
  }
  Err(Syntax("unterminated string"))
}

///|
fn starts_with_at(c : Cursor, word : String) -> Bool {
  let n = word.length()
  if c.i + n > c.src.length() {
    return false
  }
  slice_text(c.src, c.i, c.i + n) == word
}

///|
fn parse_int_text(raw : String) -> Result[Int, ODataError] {
  if raw.length() == 0 {
    return Err(Syntax("empty integer"))
  }
  let mut i = 0
  let mut neg = false
  if raw[0].to_int() == 45 {
    neg = true
    i = 1
  }
  if i >= raw.length() {
    return Err(Syntax("bad integer " + raw))
  }
  let mut n = 0
  while i < raw.length() {
    let d = raw[i].to_int() - 48
    if d < 0 || d > 9 {
      return Err(Syntax("bad integer " + raw))
    }
    n = n * 10 + d
    i = i + 1
  }
  if neg {
    Ok(0 - n)
  } else {
    Ok(n)
  }
}

///|
fn parse_float_text(raw : String) -> Result[Double, ODataError] {
  let mut i = 0
  let mut neg = false
  if raw.length() == 0 {
    return Err(Syntax("empty float"))
  }
  if raw[0].to_int() == 45 {
    neg = true
    i = 1
  }
  let mut acc = 0.0
  let mut seen = false
  while i < raw.length() && is_digit(raw[i].to_int()) {
    seen = true
    acc = acc * 10.0 + (raw[i].to_int() - 48).to_double()
    i = i + 1
  }
  if i < raw.length() && raw[i].to_int() == 46 {
    i = i + 1
    let mut place = 0.1
    let mut frac = false
    while i < raw.length() && is_digit(raw[i].to_int()) {
      frac = true
      acc = acc + (raw[i].to_int() - 48).to_double() * place
      place = place * 0.1
      i = i + 1
    }
    if !frac {
      return Err(Syntax("bad float " + raw))
    }
    seen = true
  }
  if !seen || i != raw.length() {
    return Err(Syntax("bad float " + raw))
  }
  if neg {
    Ok(0.0 - acc)
  } else {
    Ok(acc)
  }
}
