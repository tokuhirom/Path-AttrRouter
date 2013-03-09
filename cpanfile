requires 'Mouse' => '1.05';
requires 'Module::Pluggable::Object';
requires 'Text::SimpleTable' => '1.1';
requires 'Data::Util';
requires 'Class::Data::Inheritable';
requires 'Try::Tiny';

on configure => sub {
    requires 'Module::Install';
    requires 'Module::Install::Repository';
    requires 'Module::Install::CPANfile';
    requires 'Module::Install::TestBase';
    requires 'Module::Install::AuthorTests';
};

on 'test' => sub {
    requires 'Test::Base';
};
