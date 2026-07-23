with AUnit.Assertions;

with Messages.AST;
with Messages.Cache;
with Messages.Compiled;
with Messages.Compiler;
with Messages.Errors; use Messages.Errors;
with Messages.Fast_Render;
with Messages.Parser;
with Messages.Render;
with Messages.Runtime.Compatibility;
with Messages.Arguments;

package body Messages.Runtime.Tests.Compilation is

   procedure Add_Arg
     (Args : in out Messages.Arguments.Arguments; Key : String; Value : String) is
   begin
      Messages.Arguments.Set (Args => Args, Key => Key, Value => Value);
   end Add_Arg;
   procedure Test_Render_Does_Not_Recompile
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
      Source  : constant String := "Hello {name}";
   begin
      Messages.Cache.Clear;
      Add_Arg (Args, "name", "Ada");

      Messages.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "initialization should compile exactly once");

      for Iteration in 1 .. 5 loop
         declare
            Result : constant Messages.Errors.Result :=
              Messages.Runtime.Compatibility.Render (Runtime, Args);
         begin
            AUnit.Assertions.Assert
              (Condition =>
                 Result.Ok
                 and then Messages.Errors.Value_Text (Result) = "Hello Ada",
               Message   =>
                 "cached runtime render should succeed on iteration"
                 & Integer'Image (Iteration));
         end;
      end loop;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   =>
           "rendering must not parse or recompile the cached message");
      Messages.Runtime.Finalize (Runtime);
   end Test_Render_Does_Not_Recompile;

   procedure Test_Cache_Clear_Forces_Recompile
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source  : constant String := "Hello {name}";
   begin
      Messages.Cache.Clear;

      declare
         Message : Messages.Compiled.Compiled_Message;
         Result  : constant Messages.Errors.Result :=
           Messages.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Compiled.Op_Count (Message) > 0,
            Message   => "first cache compile should produce IR");
      end;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "first cache miss should compile once");

      Messages.Cache.Clear;
      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 0,
         Message   => "cache clear should reset compile count");

      declare
         Message : Messages.Compiled.Compiled_Message;
         Result  : constant Messages.Errors.Result :=
           Messages.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Compiled.Op_Count (Message) > 0,
            Message   => "compile after cache clear should produce IR");
      end;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "cache miss after clear should compile once again");
   end Test_Cache_Clear_Forces_Recompile;

   procedure Test_Invalid_Message_Is_Not_Cached
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Message : Messages.Compiled.Compiled_Message;
      Source  : constant String := "{count, plural, one {# item}}";
   begin
      Messages.Cache.Clear;

      declare
         Result : constant Messages.Errors.Result :=
           Messages.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              not Result.Ok and then Result.Error = Messages.Errors.Missing_Branch,
            Message   =>
              "invalid incomplete plural should fail validation and not compile");
      end;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 0,
         Message   =>
           "invalid messages must not increment compile count or enter cache");
   end Test_Invalid_Message_Is_Not_Cached;

   procedure Test_Compiler_Produces_Linear_IR
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : Messages.AST.Node_Access :=
        Messages.Parser.Parse
          ("Hello {name}, {count, plural, one {# item} other {# items}}");
      Msg  : constant Messages.Compiled.Compiled_Message :=
        Messages.Compiler.Compile (Root);
   begin
      AUnit.Assertions.Assert
        (Condition => Messages.Compiled.Op_Count (Msg) >= 6,
         Message   =>
           "compiled message should contain flattened text, var, branch, and stop operations");
      Messages.AST.Free (Root);
   exception
      when others =>
         Messages.AST.Free (Root);
         raise;
   end Test_Compiler_Produces_Linear_IR;

   procedure Test_Runtime_Uses_Cache_Without_Recompile
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime_1 : Messages.Runtime.Runtime;
      Runtime_2 : Messages.Runtime.Runtime;
      Args      : Messages.Arguments.Arguments;
      Source    : constant String := "Hello {name}";
   begin
      Messages.Cache.Clear;
      Add_Arg (Args, "name", "Ada");

      Messages.Runtime.Compatibility.Initialize_Message (Runtime_1, Source);
      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "first initialization should compile exactly once");

      Messages.Runtime.Compatibility.Initialize_Message (Runtime_2, Source);
      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   =>
           "second initialization of same message should be a cache hit");

      declare
         Result_1 : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime_1, Args);
         Result_2 : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime_2, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result_1.Ok
              and then Messages.Errors.Value_Text (Result_1) = "Hello Ada",
            Message   => "first cached runtime should render correctly");
         AUnit.Assertions.Assert
           (Condition =>
              Result_2.Ok
              and then Messages.Errors.Value_Text (Result_2) = "Hello Ada",
            Message   => "second cached runtime should render correctly");
      end;

      Messages.Runtime.Finalize (Runtime_1);
      Messages.Runtime.Finalize (Runtime_2);
   end Test_Runtime_Uses_Cache_Without_Recompile;

   procedure Test_Plural_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "{count, plural, one {# item} other {# items}}");
      Add_Arg (Args, "count", "2");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "2 items",
            Message   =>
              "compiled plural should select other and substitute #");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Plural_IR_Renders_Correctly;

   procedure Test_Select_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{width, select, full {hour} short {hr} narrow {h} other {hour}}");
      Add_Arg (Args, "width", "short");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "hr",
            Message   =>
              "compiled select should jump to an arbitrary named branch");
      end;

      Add_Arg (Args, "width", "unmatched");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "hour",
            Message   =>
              "compiled select should fall back to the other branch");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Select_IR_Renders_Correctly;

   procedure Test_Selectordinal_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{num, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}");
      Add_Arg (Args, "num", "3");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "3rd",
            Message   => "compiled selectordinal should select few for 3");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Selectordinal_IR_Renders_Correctly;

   procedure Test_Plural_Offset_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{count, plural, offset:1 one {# item} other {# items}}");
      Add_Arg (Args, "count", "2");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then Messages.Errors.Value_Text (Result) = "1 item",
            Message   => "compiled plural offset should adjust # and branch");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Plural_Offset_IR_Renders_Correctly;

   procedure Test_Currency_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "Total {amount, currency, USD}");
      Add_Arg (Args, "amount", "7.5");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then Messages.Errors.Value_Text (Result) = "Total $7.50",
            Message   => "compiled currency should format the amount");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Currency_IR_Renders_Correctly;

   procedure Test_Number_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "Total {value, number}");
      Add_Arg (Args, "value", "12345.5");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then Messages.Errors.Value_Text (Result) = "Total 12,345.5",
            Message   => "compiled number should format the value");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Number_IR_Renders_Correctly;

   procedure Test_Date_Time_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "On {day, date} at {clock, time}");
      Add_Arg (Args, "day", "2026-06-29");
      Add_Arg (Args, "clock", "14:30");
      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then Messages.Errors.Value_Text (Result) =
                "On 2026-06-29 at 14:30",
            Message   => "compiled date/time should format values");
      end;
      Messages.Runtime.Finalize (Runtime);
   end Test_Date_Time_IR_Renders_Correctly;

   procedure Test_AST_And_IR_Render_Are_Equivalent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "{count, plural, "
        & "=0 {Nobody has items} "
        & "one {{gender, select, "
        & "male {He has # item} "
        & "female {She has # item} "
        & "other {They have # item}}} "
        & "other {{gender, select, "
        & "male {He has # items} "
        & "female {She has # items} "
        & "other {They have # items}}}}";
      Root   : Messages.AST.Node_Access := Messages.Parser.Parse (Source);
      Msg    : constant Messages.Compiled.Compiled_Message :=
        Messages.Compiler.Compile (Root);
      Args   : Messages.Arguments.Arguments;
   begin
      Add_Arg (Args, "count", "0");
      Add_Arg (Args, "gender", "male");

      declare
         AST_Result : constant Messages.Errors.Result :=
           Messages.Render.Render (Root, Args);
         IR_Result  : constant Messages.Errors.Result :=
           Messages.Fast_Render.Render (Msg, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => AST_Result.Ok,
            Message   => "AST renderer should succeed");
         AUnit.Assertions.Assert
           (Condition => IR_Result.Ok,
            Message   => "IR renderer should succeed");
         AUnit.Assertions.Assert
           (Condition =>
              Messages.Errors.Value_Text (AST_Result)
              = Messages.Errors.Value_Text (IR_Result),
            Message   => "IR result must match AST result exactly");
      end;

      Messages.AST.Free (Root);
   exception
      when others =>
         Messages.AST.Free (Root);
         raise;
   end Test_AST_And_IR_Render_Are_Equivalent;

   procedure Test_Nested_Number_Context_Is_Restored
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Args    : Messages.Arguments.Arguments;
      Source  : constant String :=
        "{count, plural, "
        & "one {{num, selectordinal, "
        & "one {#st inner} "
        & "two {#nd inner} "
        & "few {#rd inner} "
        & "other {#th inner}} outer #} "
        & "other {outer #}}";
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      Add_Arg (Args, "count", "1");
      Add_Arg (Args, "num", "2");

      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then Messages.Errors.Value_Text (Result) = "2nd inner outer 1",
            Message   =>
              "inner ordinal # substitution must not corrupt outer plural # context");
      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Nested_Number_Context_Is_Restored;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N compiled IR/cache tests");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Compiler_Produces_Linear_IR'Access,
         "compiler emits flattened operations");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Runtime_Uses_Cache_Without_Recompile'Access,
         "repeated runtime initialization reuses cached compiled message");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Render_Does_Not_Recompile'Access,
         "repeated renders do not recompile cached message");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Cache_Clear_Forces_Recompile'Access,
         "explicit cache clear forces later recompilation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Message_Is_Not_Cached'Access,
         "invalid messages are not cached as compiled entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Plural_IR_Renders_Correctly'Access,
         "compiled plural renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Select_IR_Renders_Correctly'Access,
         "compiled select renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Selectordinal_IR_Renders_Correctly'Access,
         "compiled selectordinal renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Plural_Offset_IR_Renders_Correctly'Access,
         "compiled plural offset renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Currency_IR_Renders_Correctly'Access,
         "compiled currency renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Number_IR_Renders_Correctly'Access,
         "compiled number renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Date_Time_IR_Renders_Correctly'Access,
         "compiled date/time renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_AST_And_IR_Render_Are_Equivalent'Access,
         "AST renderer and IR renderer are exactly equivalent");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Nested_Number_Context_Is_Restored'Access,
         "nested plural/selectordinal number context is restored");
   end Register_Tests;

end Messages.Runtime.Tests.Compilation;
