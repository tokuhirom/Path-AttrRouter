use inc::Module::Install;
name 'Path-AttrRouter';
all_from 'lib/Path/AttrRouter.pm';


test_requires 'Test::More' => '0.88';
use_test_base;

tests 't/*.t t/*/*.t';
author_tests('xt');

auto_include;
auto_set_repository;
cpanfile;

WriteAll;
