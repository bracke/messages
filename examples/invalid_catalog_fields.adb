with Ada.Text_IO;
with Messages.Runtime;

procedure Invalid_Catalog_Fields is
   Runtime : Messages.Runtime.Instance;

   procedure Check
     (Label : String;
      Path  : String)
   is
   begin
      Messages.Runtime.Initialize (Runtime, Path);
      Ada.Text_IO.Put_Line
        (Label & " valid: " & Boolean'Image (Messages.Runtime.Is_Valid (Runtime)));
      Messages.Runtime.Finalize (Runtime);
   end Check;
begin
   Check ("empty locale", "examples/catalogs/invalid_empty_locale.catalog");
   Check ("empty key", "examples/catalogs/invalid_empty_key.catalog");
   Check ("empty default locale", "examples/catalogs/invalid_empty_default_locale.catalog");
end Invalid_Catalog_Fields;
