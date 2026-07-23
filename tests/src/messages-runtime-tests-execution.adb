with AUnit.Assertions;

with Messages.Buffer;
with Messages.Cache;
with Messages.Compiled;
with Messages.Errors; use Messages.Errors;
with Messages.Runtime.Compatibility;
with Messages.Arguments;

package body Messages.Runtime.Tests.Execution is

   procedure Add_Arg
     (Args  : in out Messages.Arguments.Arguments;
      Key   : String;
      Value : String)
   is
   begin
      Messages.Arguments.Set
        (Args  => Args,
         Key   => Key,
         Value => Value);
   end Add_Arg;

   procedure Test_Context_Render_Is_Deterministic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Buffer_Overflow_Is_Deterministic_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Concurrent_Render_Same_Runtime
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Branches_Are_Correct_Under_Repeated_Context_Reuse
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Cache_Get_Is_Read_Only_After_Fill
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Render_Into_Uses_Caller_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String
   is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N zero-allocation/concurrency tests");
   end Name;

   overriding procedure Register_Tests
     (T : in out Test_Case)
   is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Context_Render_Is_Deterministic'Access,
         "per-thread execution context renders deterministically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Buffer_Overflow_Is_Deterministic_Error'Access,
         "fixed output buffer overflow is a deterministic error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Concurrent_Render_Same_Runtime'Access,
         "multiple tasks render one immutable runtime concurrently");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Branches_Are_Correct_Under_Repeated_Context_Reuse'Access,
         "plural/select/selectordinal branches remain correct with context reuse");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Cache_Get_Is_Read_Only_After_Fill'Access,
         "cache get exposes an initialized immutable message without recompilation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Render_Into_Uses_Caller_Buffer'Access,
         "strict render_into writes caller buffer and returns status only");
   end Register_Tests;

   procedure Test_Context_Render_Is_Deterministic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Context : Messages.Runtime.Compatibility.Execution_Context;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "Hello {name}, {count, plural, one {# item} other {# items}}");
      Add_Arg (Context.Args, "name", "Ada");
      Add_Arg (Context.Args, "count", "2");

      for Iteration in 1 .. 32 loop
         declare
            Result : constant Messages.Errors.Result :=
              Messages.Runtime.Compatibility.Render (Runtime, Context);
         begin
            AUnit.Assertions.Assert
              (Condition => Result.Ok and then Messages.Errors.Value_Text (Result) = "Hello Ada, 2 items",
               Message   => "context render should be deterministic on iteration" & Integer'Image (Iteration));
            AUnit.Assertions.Assert
              (Condition => Messages.Buffer.Length (Context.Buffer) = Messages.Errors.Value_Text (Result)'Length,
               Message   => "context buffer length should match materialized result");
         end;
      end loop;

      Messages.Runtime.Finalize (Runtime);
   end Test_Context_Render_Is_Deterministic;

   procedure Test_Buffer_Overflow_Is_Deterministic_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Context : Messages.Runtime.Compatibility.Execution_Context;
      Large   : constant String (1 .. Messages.Buffer.Default_Capacity + 1) :=
        (others => 'x');
   begin
      Messages.Runtime.Compatibility.Initialize_Message (Runtime, "{value}");
      Add_Arg (Context.Args, "value", Large);

      declare
         Result : constant Messages.Errors.Result :=
           Messages.Runtime.Compatibility.Render (Runtime, Context);
      begin
         AUnit.Assertions.Assert
           (Condition => not Result.Ok and then Result.Error = Messages.Errors.Buffer_Overflow,
            Message   => "render-time fixed buffer overflow must fail deterministically");
      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Buffer_Overflow_Is_Deterministic_Error;

   procedure Test_Concurrent_Render_Same_Runtime
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Failures : array (1 .. 4) of Boolean := [others => False]
        with Atomic_Components;

      task type Worker is
         entry Start (Index : Positive);
      end Worker;

      task body Worker is
         Id      : Positive := 1;
         Context : Messages.Runtime.Compatibility.Execution_Context;
      begin
         accept Start (Index : Positive) do
            Id := Index;
         end Start;

         Add_Arg (Context.Args, "gender", "female");
         Add_Arg (Context.Args, "count", "3");
         Add_Arg (Context.Args, "num", "2");

         for Iteration in 1 .. 128 loop
            declare
               Result : constant Messages.Errors.Result :=
                 Messages.Runtime.Compatibility.Render (Runtime, Context);
            begin
               if not Result.Ok or else Messages.Errors.Value_Text (Result) /= "She has 3 items and is 2nd" then
                  Failures (Id) := True;
               end if;
            end;
         end loop;
      exception
         when others =>
            Failures (Id) := True;
      end Worker;

   begin
      Messages.Cache.Clear;
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{gender, select, male {He} female {She} other {They}} has " &
         "{count, plural, one {# item} other {# items}} and is " &
         "{num, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}");

      declare
         Workers : array (1 .. 4) of Worker;
      begin
         for Index in Workers'Range loop
            Workers (Index).Start (Index);
         end loop;
      end;

      for Index in Failures'Range loop
         AUnit.Assertions.Assert
           (Condition => not Failures (Index),
            Message   => "concurrent worker" & Integer'Image (Index) & " should render identical output");
      end loop;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "concurrent render must not mutate cache or recompile messages");

      Messages.Runtime.Finalize (Runtime);
   end Test_Concurrent_Render_Same_Runtime;

   procedure Test_Branches_Are_Correct_Under_Repeated_Context_Reuse
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Context : Messages.Runtime.Compatibility.Execution_Context;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{count, plural, one {one/#} other {other/#}} " &
         "{gender, select, male {M} female {F} other {O}} " &
         "{num, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}");
      Add_Arg (Context.Args, "gender", "male");
      Add_Arg (Context.Args, "count", "1");
      Add_Arg (Context.Args, "num", "3");

      declare
         Result : constant Messages.Errors.Result := Messages.Runtime.Compatibility.Render (Runtime, Context);
      begin
         AUnit.Assertions.Assert
           (Condition => Result.Ok and then Messages.Errors.Value_Text (Result) = "one/1 M 3rd",
            Message   => "first branch combination should render correctly");
      end;

      Add_Arg (Context.Args, "gender", "other");
      Add_Arg (Context.Args, "count", "4");
      Add_Arg (Context.Args, "num", "9");

      declare
         Result : constant Messages.Errors.Result := Messages.Runtime.Compatibility.Render (Runtime, Context);
      begin
         AUnit.Assertions.Assert
           (Condition => Result.Ok and then Messages.Errors.Value_Text (Result) = "other/4 O 9th",
            Message   => "second branch combination should render correctly using same context");
      end;

      Messages.Runtime.Finalize (Runtime);
   end Test_Branches_Are_Correct_Under_Repeated_Context_Reuse;

   procedure Test_Cache_Get_Is_Read_Only_After_Fill
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source  : constant String := "Cached {name}";
      Message : Messages.Compiled.Compiled_Message;
   begin
      Messages.Cache.Clear;

      declare
         Status : constant Messages.Errors.Result :=
           Messages.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition => Status.Ok,
            Message   => "first cache fill should compile successfully");
      end;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Contains (Source),
         Message   => "cache should contain source after successful fill");
      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "cache should have exactly one compile after first fill");

      declare
         Cached : constant Messages.Compiled.Compiled_Message :=
           Messages.Cache.Get (Source);
      begin
         AUnit.Assertions.Assert
           (Condition => Messages.Compiled.Op_Count (Cached) =
                         Messages.Compiled.Op_Count (Message),
            Message   => "read-only cache get should expose same operation count");
      end;

      AUnit.Assertions.Assert
        (Condition => Messages.Cache.Compile_Count = 1,
         Message   => "read-only cache get must not compile or mutate cache");
   end Test_Cache_Get_Is_Read_Only_After_Fill;

   procedure Test_Render_Into_Uses_Caller_Buffer
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : Messages.Runtime.Runtime;
      Context : Messages.Runtime.Compatibility.Execution_Context;
      Status  : Messages.Errors.Status;
   begin
      Messages.Runtime.Compatibility.Initialize_Message
        (Runtime, "Hi {name}, {count, plural, one {# file} other {# files}}");
      Add_Arg (Context.Args, "name", "Ada");
      Add_Arg (Context.Args, "count", "5");

      Status := Messages.Runtime.Compatibility.Render_Into (Runtime, Context);

      AUnit.Assertions.Assert
        (Condition => Status.Ok,
         Message   => "render_into should return success status");
      AUnit.Assertions.Assert
        (Condition => Messages.Buffer.To_String (Context.Buffer) = "Hi Ada, 5 files",
         Message   => "render_into should write rendered text to caller-owned buffer");

      Messages.Runtime.Finalize (Runtime);
   end Test_Render_Into_Uses_Caller_Buffer;

end Messages.Runtime.Tests.Execution;
