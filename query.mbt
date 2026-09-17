///|
pub(all) struct OrderByItem {
  path : Array[String]
  desc : Bool
} derive(Eq, Debug)

///|
pub(all) struct ExpandItem {
  path : Array[String]
  nested : QueryOptions?
} derive(Eq, Debug)

///|
pub(all) struct QueryOptions {
  mut filter : Filter?
  mut select : Array[String]?
  mut expand : Array[ExpandItem]?
  mut orderby : Array[OrderByItem]?
  mut top : Int?
  mut skip : Int?
  mut count : Bool?
  mut search : String?
  mut format_ : String?
} derive(Eq, Debug)

///|
pub fn empty_query() -> QueryOptions {
  {
    filter: None,
    select: None,
    expand: None,
    orderby: None,
    top: None,
    skip: None,
    count: None,
    search: None,
    format_: None,
  }
}

///|
fn parse_ident_list(text : String) -> Result[Array[String], ODataError] {
  let c = cursor_new(text)
  let items : Array[String] = []
  skip_ws(c)
  if cursor_eof(c) {
    return Err(Syntax("empty identifier list"))
  }
  while true {
    skip_ws(c)
    if !is_ident_start(cursor_peek(c)) && cursor_peek(c) != 42 {
      return Err(Syntax("expected select item"))
    }
    if cursor_peek(c) == 42 {
      items.push("*")
      cursor_bump(c)
    } else {
      items.push(read_ident(c))
    }
    skip_ws(c)
    if cursor_peek(c) == 44 {
      cursor_bump(c)
    } else {
      break
    }
  }
  skip_ws(c)
  if cursor_eof(c) {
    Ok(items)
  } else {
    Err(Syntax("trailing select content"))
  }
}

///|
fn parse_orderby(text : String) -> Result[Array[OrderByItem], ODataError] {
  let c = cursor_new(text)
  let items : Array[OrderByItem] = []
  skip_ws(c)
  while true {
    skip_ws(c)
    if !is_ident_start(cursor_peek(c)) {
      return Err(Syntax("expected orderby path"))
    }
    let parts : Array[String] = [read_ident(c)]
    while cursor_peek(c) == 47 {
      cursor_bump(c)
      parts.push(read_ident(c))
    }
    skip_ws(c)
    let mut desc = false
    if starts_with_at(c, "desc") && !is_ident_part(cursor_peek_at(c, 4)) {
      desc = true
      c.i += 4
    } else if starts_with_at(c, "asc") && !is_ident_part(cursor_peek_at(c, 3)) {
      c.i += 3
    }
    items.push({ path: parts, desc, })
    skip_ws(c)
    if cursor_peek(c) == 44 {
      cursor_bump(c)
    } else {
      break
    }
  }
  skip_ws(c)
  if cursor_eof(c) {
    Ok(items)
  } else {
    Err(Syntax("trailing orderby content"))
  }
}

///|
fn parse_expand(text : String) -> Result[Array[ExpandItem], ODataError] {
  let c = cursor_new(text)
  let items : Array[ExpandItem] = []
  skip_ws(c)
  while true {
    skip_ws(c)
    if !is_ident_start(cursor_peek(c)) {
      return Err(Syntax("expected expand path"))
    }
    let parts : Array[String] = [read_ident(c)]
    while cursor_peek(c) == 47 {
      cursor_bump(c)
      parts.push(read_ident(c))
    }
    items.push({ path: parts, nested: None, })
    skip_ws(c)
    if cursor_peek(c) == 44 {
      cursor_bump(c)
    } else {
      break
    }
  }
  skip_ws(c)
  if cursor_eof(c) {
    Ok(items)
  } else {
    Err(Syntax("trailing expand content"))
  }
}

///|
fn parse_bool_option(text : String) -> Result[Bool, ODataError] {
  if text == "true" {
    Ok(true)
  } else if text == "false" {
    Ok(false)
  } else {
    Err(Syntax("expected true or false"))
  }
}

///|
pub fn parse_query(text : String) -> Result[QueryOptions, ODataError] {
  let q = empty_query()
  if text.length() == 0 {
    return Ok(q)
  }
  let c = cursor_new(text)
  if cursor_peek(c) == 63 {
    cursor_bump(c)
  }
  while !cursor_eof(c) {
    skip_ws(c)
    if cursor_eof(c) {
      break
    }
    let name = read_ident(c)
    skip_ws(c)
    if cursor_peek(c) != 61 {
      return Err(Syntax("expected '=' after " + name))
    }
    cursor_bump(c)
    let start = c.i
    while !cursor_eof(c) && cursor_peek(c) != 38 {
      cursor_bump(c)
    }
    let raw = slice_text(c.src, start, c.i)
    match name {
      "$filter" =>
        match parse_filter(percent_decode(raw)) {
          Ok(f) => q.filter = Some(f)
          Err(e) => return Err(e)
        }
      "$select" =>
        match parse_ident_list(percent_decode(raw)) {
          Ok(xs) => q.select = Some(xs)
          Err(e) => return Err(e)
        }
      "$expand" =>
        match parse_expand(percent_decode(raw)) {
          Ok(xs) => q.expand = Some(xs)
          Err(e) => return Err(e)
        }
      "$orderby" =>
        match parse_orderby(percent_decode(raw)) {
          Ok(xs) => q.orderby = Some(xs)
          Err(e) => return Err(e)
        }
      "$top" =>
        match parse_int_text(raw) {
          Ok(n) => q.top = Some(n)
          Err(e) => return Err(e)
        }
      "$skip" =>
        match parse_int_text(raw) {
          Ok(n) => q.skip = Some(n)
          Err(e) => return Err(e)
        }
      "$count" =>
        match parse_bool_option(raw) {
          Ok(b) => q.count = Some(b)
          Err(e) => return Err(e)
        }
      "$search" => q.search = Some(percent_decode(raw))
      "$format" => q.format_ = Some(raw)
      _ => return Err(Syntax("unknown query option " + name))
    }
    if cursor_peek(c) == 38 {
      cursor_bump(c)
    }
  }
  Ok(q)
}

///|
fn percent_decode(text : String) -> String {
  let mut out = ""
  let mut i = 0
  while i < text.length() {
    let ch = text[i].to_int()
    if ch == 37 && i + 2 < text.length() {
      let hi = hex_val(text[i + 1].to_int())
      let lo = hex_val(text[i + 2].to_int())
      if hi >= 0 && lo >= 0 {
        out = out + code_to_char(hi * 16 + lo)
        i = i + 3
        continue
      }
    } else if ch == 43 {
      out = out + " "
      i = i + 1
      continue
    }
    out = out + slice_text(text, i, i + 1)
    i = i + 1
  }
  out
}

///|
fn hex_val(ch : Int) -> Int {
  if ch >= 48 && ch <= 57 {
    ch - 48
  } else if ch >= 65 && ch <= 70 {
    ch - 55
  } else if ch >= 97 && ch <= 102 {
    ch - 87
  } else {
    -1
  }
}

///|
fn code_to_char(code : Int) -> String {
  match code {
    32 => " "
    33 => "!"
    36 => "$"
    38 => "&"
    39 => "'"
    40 => "("
    41 => ")"
    42 => "*"
    44 => ","
    47 => "/"
    58 => ":"
    61 => "="
    63 => "?"
    _ => {
      if code >= 48 && code <= 57 {
        slice_text("0123456789", code - 48, code - 47)
      } else if code >= 65 && code <= 90 {
        slice_text("ABCDEFGHIJKLMNOPQRSTUVWXYZ", code - 65, code - 64)
      } else if code >= 97 && code <= 122 {
        slice_text("abcdefghijklmnopqrstuvwxyz", code - 97, code - 96)
      } else {
        "?"
      }
    }
  }
}

///|
fn percent_encode_query(text : String) -> String {
  let mut out = ""
  let mut i = 0
  while i < text.length() {
    let ch = text[i].to_int()
    if is_ident_part(ch) || ch == 45 || ch == 46 || ch == 126 || ch == 32 {
      if ch == 32 {
        out = out + "%20"
      } else {
        out = out + slice_text(text, i, i + 1)
      }
    } else if ch == 39 {
      out = out + "%27"
    } else if ch == 40 {
      out = out + "%28"
    } else if ch == 41 {
      out = out + "%29"
    } else if ch == 44 {
      out = out + "%2C"
    } else if ch == 47 {
      out = out + "%2F"
    } else {
      out = out + slice_text(text, i, i + 1)
    }
    i = i + 1
  }
  out
}

///|
pub fn QueryOptions::to_url(self : QueryOptions) -> String {
  let parts : Array[String] = []
  match self.filter {
    Some(f) => parts.push("$filter=" + percent_encode_query(f.to_url()))
    None => ()
  }
  match self.select {
    Some(xs) => {
      let mut s = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          s = s + ","
        }
        s = s + xs[i]
        i = i + 1
      }
      parts.push("$select=" + s)
    }
    None => ()
  }
  match self.expand {
    Some(xs) => {
      let mut s = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          s = s + ","
        }
        let mut p = ""
        let mut j = 0
        while j < xs[i].path.length() {
          if j > 0 {
            p = p + "/"
          }
          p = p + xs[i].path[j]
          j = j + 1
        }
        s = s + p
        i = i + 1
      }
      parts.push("$expand=" + s)
    }
    None => ()
  }
  match self.orderby {
    Some(xs) => {
      let mut s = ""
      let mut i = 0
      while i < xs.length() {
        if i > 0 {
          s = s + ","
        }
        let mut p = ""
        let mut j = 0
        while j < xs[i].path.length() {
          if j > 0 {
            p = p + "/"
          }
          p = p + xs[i].path[j]
          j = j + 1
        }
        if xs[i].desc {
          s = s + p + " desc"
        } else {
          s = s + p
        }
        i = i + 1
      }
      parts.push("$orderby=" + s)
    }
    None => ()
  }
  match self.top {
    Some(n) => parts.push("$top=" + n.to_string())
    None => ()
  }
  match self.skip {
    Some(n) => parts.push("$skip=" + n.to_string())
    None => ()
  }
  match self.count {
    Some(true) => parts.push("$count=true")
    Some(false) => parts.push("$count=false")
    None => ()
  }
  match self.search {
    Some(s) => parts.push("$search=" + percent_encode_query(s))
    None => ()
  }
  match self.format_ {
    Some(s) => parts.push("$format=" + s)
    None => ()
  }
  if parts.length() == 0 {
    ""
  } else {
    let mut out = "?"
    let mut i = 0
    while i < parts.length() {
      if i > 0 {
        out = out + "&"
      }
      out = out + parts[i]
      i = i + 1
    }
    out
  }
}
