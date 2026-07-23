with Example_Support;
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Time_Formatting is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   Messages.Arguments.Set (Args, "clock", "09:05:07");

   declare
      Short_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.short", Args);
      Long_Result  : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.long", Args);
      Skeleton_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.skeleton", Args);
   begin
      Example_Support.Print_Result ("time short", Short_Result);
      Example_Support.Print_Result ("time long", Long_Result);
      Example_Support.Print_Result ("time skeleton", Skeleton_Result);
   end;

   Messages.Arguments.Set (Args, "clock", "09:05:07.123");

   declare
      Fraction_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.fraction", Args);
   begin
      Example_Support.Print_Result ("time fraction", Fraction_Result);
   end;

   Messages.Arguments.Set (Args, "instant", "2024-02-29T14:05:07Z");

   declare
      Zone_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.zone", Args);
   begin
      Example_Support.Print_Result ("time zone", Zone_Result);
   end;

   Messages.Arguments.Set (Args, "instant", "2024-07-01T12:00:00Z");

   declare
      Zone_Widths_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.zone_widths", Args);
      UTC_Widths_Result  : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.utc_widths", Args);
   begin
      Example_Support.Print_Result ("time zone widths", Zone_Widths_Result);
      Example_Support.Print_Result ("time utc widths", UTC_Widths_Result);
   end;

   Messages.Arguments.Set (Args, "instant", "2024-03-01T02:30:00Z");

   declare
      Long_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.datetime_long", Args);
      Full_Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render (Runtime, "en", "time.datetime_full", Args);
   begin
      Example_Support.Print_Result ("time datetime long", Long_Result);
      Example_Support.Print_Result ("time datetime full", Full_Result);
   end;
end Time_Formatting;
