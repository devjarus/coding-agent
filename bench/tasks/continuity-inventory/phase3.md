Next change to the inventory service in this repo: a stock movement log.

Every time a stock quantity actually changes through `PUT /items/{sku}/stock/{code}`, record a movement `{"id", "sku", "warehouse", "delta", "qty_after", "at"}` (`delta` = new qty − old qty; setting the same qty again records nothing). `GET /items/{sku}/movements` lists an item's movements oldest first; unknown item → not found.

Same API conventions as the rest of the service.
