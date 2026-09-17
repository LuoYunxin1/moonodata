# Architecture

1. `parse_url` splits service root, resource path and query string.
2. `$filter` is a recursive-descent AST (`eq`/`and`/`or`/`not`/functions).
3. `parse_payload` reads OData JSON annotations; encode writes the same keys.
4. `parse_metadata` scans EDMX tags for EntityType/EntitySet without a full XML DOM.
5. `validate_request` checks `$top`/`$skip`, function arity, and optional EDM entity-set names.

No network I/O. Callers supply URL text, JSON text, or EDMX text.
