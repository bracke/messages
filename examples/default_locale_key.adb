with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Default_Locale_Key is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "fr-CA", "plain", Args);
   begin
      Example_Support.Print_Result ("unqualified catalog key uses default locale", Result);
   end;
end Default_Locale_Key;
