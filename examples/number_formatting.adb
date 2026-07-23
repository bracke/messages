with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Number_Formatting is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "value", "12345.67");

   declare
      En_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.total", Args);
      De_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "de", "number.total", Args);
   begin
      Example_Support.Print_Result ("number en", En_Result);
      Example_Support.Print_Result ("number de", De_Result);
   end;

   Messages.Arguments.Set (Args, "value", "0.125");

   declare
      Percent_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.percent", Args);
      Permille_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.permille", Args);
   begin
      Example_Support.Print_Result ("number percent", Percent_Result);
      Example_Support.Print_Result ("number permille", Permille_Result);
   end;

   Messages.Arguments.Set (Args, "value", "12345");

   declare
      Compact_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.compact", Args);
      Scientific_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.scientific", Args);
      Engineering_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.engineering", Args);
   begin
      Example_Support.Print_Result ("number compact", Compact_Result);
      Example_Support.Print_Result ("number scientific", Scientific_Result);
      Example_Support.Print_Result ("number engineering", Engineering_Result);
   end;

   Messages.Arguments.Set (Args, "value", "42");

   declare
      Spellout_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.spellout", Args);
      Trailing_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.trailing", Args);
   begin
      Example_Support.Print_Result ("number spellout", Spellout_Result);
      Example_Support.Print_Result ("number trailing", Trailing_Result);
   end;

   Messages.Arguments.Set (Args, "value", "-12345");

   declare
      Accounting_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.accounting", Args);
   begin
      Example_Support.Print_Result
        ("number accounting", Accounting_Result);
   end;

   Messages.Arguments.Set (Args, "value", "12345.67");

   declare
      Scale_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "number.scale", Args);
   begin
      Example_Support.Print_Result ("number scale", Scale_Result);
   end;

   Messages.Arguments.Set (Args, "value", "1234567.89");

   declare
      Arabic_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "ar", "number.total", Args);
      India_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "hi-IN", "number.total", Args);
   begin
      Example_Support.Print_Result ("number arabic digits", Arabic_Result);
      Example_Support.Print_Result ("number indian grouping", India_Result);
   end;
end Number_Formatting;
