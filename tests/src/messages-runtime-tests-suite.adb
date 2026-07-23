with Messages.Runtime.Tests.Strict;
with Messages.Runtime.Tests.Compilation;
with Messages.Runtime.Tests.Execution;
with Messages.Runtime.Tests.Diagnostics;
with Messages.Runtime.Tests.Corpus;
with Messages.Runtime.Tests.Release;
with Messages.Runtime.Tests.Features;

package body Messages.Runtime.Tests.Suite is

   function Suite
      return AUnit.Test_Suites.Access_Test_Suite
   is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (new Messages.Runtime.Tests.Strict.Test_Case);
      Result.Add_Test (new Messages.Runtime.Tests.Compilation.Test_Case);
      Result.Add_Test (new Messages.Runtime.Tests.Execution.Test_Case);
      Result.Add_Test (new Messages.Runtime.Tests.Diagnostics.Test_Case);
      Result.Add_Test (new Messages.Runtime.Tests.Corpus.Test_Case);
      Result.Add_Test (new Messages.Runtime.Tests.Release.Test_Case);
      Result.Add_Test (new Messages.Runtime.Tests.Features.Test_Case);
      return Result;
   end Suite;

end Messages.Runtime.Tests.Suite;
