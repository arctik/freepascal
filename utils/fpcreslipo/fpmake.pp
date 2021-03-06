{$ifndef ALLPACKAGES}
{$mode objfpc}{$H+}
program fpmake;

uses fpmkunit;
{$endif ALLPACKAGES}

procedure add_fpcreslipo;

Var
  P : TPackage;
  T : TTarget;

begin
  With Installer do
    begin
    P:=AddPackage('fpcreslipo');

    P.Author := 'Giulio Bernardi';
    P.License := 'LGPL with modification';
    P.HomepageURL := 'www.freepascal.org';
    P.Email := '';

{$ifdef ALLPACKAGES}
    P.Directory:='fpcreslipo';
{$endif ALLPACKAGES}
    P.Version:='2.7.1';
    P.Dependencies.Add('fcl-res');

    P.OSes:=[darwin, iphonesim];

    P.Targets.AddImplicitUnit('msghandler.pp');
    P.Targets.AddImplicitUnit('paramparser.pp');
    P.Targets.AddImplicitUnit('sourcehandler.pp');
    P.Targets.AddImplicitUnit('fpcreslipo.pp');

    T:=P.Targets.AddProgram('fpcreslipo.pp');

    end;
end;

{$ifndef ALLPACKAGES}
begin
  add_fpcreslipo;
  Installer.Run;
end.
{$endif ALLPACKAGES}




