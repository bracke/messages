with Ada.Text_IO;
with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Invalid_Catalog is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize
     (Runtime, "examples/catalogs/invalid_duplicate.catalog");

   Ada.Text_IO.Put_Line
     ("duplicate catalog valid: " & Boolean'Image (Messages.Runtime.Is_Valid (Runtime)));

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Status ("render after invalid catalog", Result);
   end;

   Messages.Runtime.Initialize
     (Runtime, "examples/catalogs/invalid_syntax.catalog");

   Ada.Text_IO.Put_Line
     ("syntax catalog valid: " & Boolean'Image (Messages.Runtime.Is_Valid (Runtime)));
end Invalid_Catalog;
