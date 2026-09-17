///|
pub(all) struct ODataEntity {
  properties : Map[String, Json]
} derive(Eq, Debug)

///|
pub(all) enum ODataDocument {
  EntitySet(String, Array[ODataEntity], Int?)
  Entity(String, ODataEntity)
  Primitive(Json)
  DocError(Int, String)
} derive(Eq, Debug)

///|
pub fn parse_json_text(text : String) -> Result[Json, ODataError] {
  Ok(@json.parse(text)) catch {
    _ => Err(JsonParse("invalid JSON"))
  }
}

///|
fn expect_object(json : Json, what : String) -> Result[Map[String, Json], ODataError] {
  match json {
    Object(obj) => Ok(obj)
    _ => Err(TypeMismatch(what + " must be an object"))
  }
}

///|
fn expect_array(json : Json, what : String) -> Result[Array[Json], ODataError] {
  match json {
    Array(arr) => Ok(arr)
    _ => Err(TypeMismatch(what + " must be an array"))
  }
}

///|
fn opt_string(obj : Map[String, Json], key : String) -> Result[String?, ODataError] {
  match obj.get(key) {
    None => Ok(None)
    Some(String(s)) => Ok(Some(s))
    Some(_) => Err(TypeMismatch(key + " must be a string"))
  }
}

///|
fn json_int_opt(obj : Map[String, Json], key : String) -> Result[Int?, ODataError] {
  match obj.get(key) {
    None => Ok(None)
    Some(Number(n, ..)) => {
      if n != n.floor() {
        return Err(TypeMismatch(key + " must be an integer"))
      }
      Ok(Some(n.to_int()))
    }
    Some(_) => Err(TypeMismatch(key + " must be a number"))
  }
}

///|
fn entity_from_object(obj : Map[String, Json]) -> ODataEntity {
  let props : Array[(String, Json)] = []
  for k, v in obj {
    if !k.has_prefix("@odata.") {
      props.push((k, v))
    }
  }
  { properties: map_from_pairs(props) }
}

///|
pub fn parse_payload(text : String) -> Result[ODataDocument, ODataError] {
  match parse_json_text(text) {
    Err(e) => Err(e)
    Ok(json) => {
      match expect_object(json, "payload") {
        Err(e) => Err(e)
        Ok(obj) => {
          match obj.get("error") {
            Some(Object(err)) => {
              let code = match json_int_opt(err, "code") {
                Ok(Some(n)) => n
                _ => 400
              }
              let msg = match opt_string(err, "message") {
                Ok(Some(s)) => s
                _ => "odata error"
              }
              return Ok(DocError(code, msg))
            }
            _ => ()
          }
          let ctx = match opt_string(obj, "@odata.context") {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          match obj.get("value") {
            Some(arrjson) => {
              match expect_array(arrjson, "value") {
                Err(e) => Err(e)
                Ok(arr) => {
                  let ents : Array[ODataEntity] = []
                  let mut i = 0
                  while i < arr.length() {
                    match expect_object(arr[i], "entity") {
                      Ok(o) => ents.push(entity_from_object(o))
                      Err(e) => return Err(e)
                    }
                    i = i + 1
                  }
                  let count = match json_int_opt(obj, "@odata.count") {
                    Ok(v) => v
                    Err(e) => return Err(e)
                  }
                  let context = match ctx {
                    Some(s) => s
                    None => ""
                  }
                  Ok(EntitySet(context, ents, count))
                }
              }
            }
            None => {
              let context = match ctx {
                Some(s) => s
                None => ""
              }
              Ok(Entity(context, entity_from_object(obj)))
            }
          }
        }
      }
    }
  }
}

///|
fn json_int(n : Int) -> Json {
  Json::number(n.to_double(), repr=n.to_string())
}

///|
pub fn encode_payload(doc : ODataDocument) -> Json {
  match doc {
    EntitySet(ctx, ents, count) => {
      let pairs : Array[(String, Json)] = []
      if ctx.length() > 0 {
        pairs.push(("@odata.context", Json::string(ctx)))
      }
      match count {
        Some(n) => pairs.push(("@odata.count", json_int(n)))
        None => ()
      }
      let arr : Array[Json] = []
      let mut i = 0
      while i < ents.length() {
        arr.push(Json::object(ents[i].properties))
        i = i + 1
      }
      pairs.push(("value", Json::array(arr)))
      Json::object(map_from_pairs(pairs))
    }
    Entity(ctx, ent) => {
      let pairs : Array[(String, Json)] = []
      if ctx.length() > 0 {
        pairs.push(("@odata.context", Json::string(ctx)))
      }
      for k, v in ent.properties {
        pairs.push((k, v))
      }
      Json::object(map_from_pairs(pairs))
    }
    Primitive(j) => j
    DocError(code, msg) => {
      Json::object(
        map_from_pairs(
          [
            (
              "error",
              Json::object(
                map_from_pairs(
                  [("code", json_int(code)), ("message", Json::string(msg))],
                ),
              ),
            ),
          ],
        ),
      )
    }
  }
}
