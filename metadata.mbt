///|
fn attr_value(tag : String, name : String) -> String? {
  let key = name + "=\""
  match find_at(tag, key, 0) {
    Some(at) => {
      let start = at + key.length()
      match find_at(tag, "\"", start) {
        Some(end) => Some(slice_text(tag, start, end))
        None => None
      }
    }
    None => {
      let key2 = name + "='"
      match find_at(tag, key2, 0) {
        Some(at) => {
          let start = at + key2.length()
          match find_at(tag, "'", start) {
            Some(end) => Some(slice_text(tag, start, end))
            None => None
          }
        }
        None => None
      }
    }
  }
}

///|
fn next_tag(xml : String, i : Int) -> (Int, String)? {
  match find_at(xml, "<", i) {
    None => None
    Some(a) =>
      match find_at(xml, ">", a) {
        None => None
        Some(b) => Some((b + 1, slice_text(xml, a, b + 1)))
      }
  }
}

///|
pub fn parse_metadata(xml : String) -> Result[EdmSchema, ODataError] {
  let types : Array[EntityType] = []
  let sets : Array[EntitySet] = []
  let mut ns = ""
  let mut i = 0
  let mut current : EntityType? = None
  while true {
    match next_tag(xml, i) {
      None => break
      Some((ni, tag)) => {
        i = ni
        if tag.has_prefix("<Schema") {
          match attr_value(tag, "Namespace") {
            Some(v) => ns = v
            None => ()
          }
        } else if tag.has_prefix("<EntityType") {
          let name = match attr_value(tag, "Name") {
            Some(v) => v
            None => return Err(Metadata("EntityType missing Name"))
          }
          match current {
            Some(t) => types.push(t)
            None => ()
          }
          current = Some({ name, key: [], properties: [], })
        } else if tag.has_prefix("</EntityType") {
          match current {
            Some(t) => {
              types.push(t)
              current = None
            }
            None => ()
          }
        } else if tag.has_prefix("<PropertyRef") {
          match attr_value(tag, "Name") {
            Some(k) =>
              match current {
                Some(t) => {
                  t.key.push(k)
                  current = Some(t)
                }
                None => ()
              }
            None => ()
          }
        } else if tag.has_prefix("<Property") && !tag.has_prefix("<PropertyRef") {
          let name = match attr_value(tag, "Name") {
            Some(v) => v
            None => return Err(Metadata("Property missing Name"))
          }
          let tw = match attr_value(tag, "Type") {
            Some(v) => v
            None => "Edm.String"
          }
          let nullable = match attr_value(tag, "Nullable") {
            Some("false") => false
            _ => true
          }
          match current {
            Some(t) => {
              t.properties.push({ name, type_: EdmType::from_wire(tw), nullable, })
              current = Some(t)
            }
            None => ()
          }
        } else if tag.has_prefix("<EntitySet") {
          let name = match attr_value(tag, "Name") {
            Some(v) => v
            None => return Err(Metadata("EntitySet missing Name"))
          }
          let ty = match attr_value(tag, "EntityType") {
            Some(v) => v
            None => name
          }
          sets.push({ name, type_: ty, })
        }
      }
    }
  }
  match current {
    Some(t) => types.push(t)
    None => ()
  }
  if types.length() == 0 && sets.length() == 0 {
    return Err(Metadata("no EntityType or EntitySet found"))
  }
  Ok({ ns_: ns, entity_types: types, entity_sets: sets, })
}
