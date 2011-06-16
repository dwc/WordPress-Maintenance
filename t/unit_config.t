use strict;
use warnings;
use File::Spec;
use FindBin;
use WordPress::Maintenance::Config;

use Test::More tests => 67;

my $config = WordPress::Maintenance::Config->new(File::Spec->join($FindBin::Dir, 'site'));
isa_ok($config, 'WordPress::Maintenance::Config');

my $dev = $config->for_environment('dev');
is($dev->{server_group}, 'apache');
is($dev->{user}, undef);
is($dev->{group}, 'webadmin');
is($dev->{path}, '/var/www/dev.webadmin.ufl.edu/htdocs/test');
isa_ok($dev->{uri}, 'URI');
is($dev->{uri}, 'http://dev.webadmin.ufl.edu/test');
is($dev->{uri}->host, 'dev.webadmin.ufl.edu');
is($dev->{uri}->path, '/test');
is($dev->{base}, '/test/');
is($dev->{shebang}, undef);
is($dev->{exclude_robots}, 1);
is($dev->{wordpress}->{wp_cache}->{enabled}, 0);
is($dev->{wordpress}->{options}->{fake_cache_ttl}, 300);
is($dev->{database}->{host}, 'localhost');
is($dev->{database}->{port}, undef);
is($dev->{database}->{user}, 'test');
is($dev->{database}->{password}, 'secret1');
is($dev->{database}->{name}, 'test');
is($dev->{database}->{dump_encoding}, 'utf8');

my $test = $config->for_environment('test');
is($test->{server_group}, undef);
is($test->{user}, 'wwwuf');
is($test->{group}, 'webuf');
is($test->{path}, '/nerdc/www/test.test.ufl.edu');
isa_ok($test->{uri}, 'URI');
is($test->{uri}, 'http://test.test.ufl.edu');
is($test->{uri}->host, 'test.test.ufl.edu');
is($test->{uri}->path, '');
is($test->{base}, '/');
is($test->{shebang}, '#!/usr/local/bin/php');
is($test->{exclude_robots}, 1);
is($test->{wordpress}->{wp_cache}->{enabled}, 1);
is($test->{wordpress}->{options}->{fake_cache_ttl}, 3600);
is($test->{database}->{host}, 'mysql01.osg.ufl.edu');
is($test->{database}->{port}, 3306);
is($test->{database}->{user}, 'test');
is($test->{database}->{password}, 'secret2');
is($test->{database}->{name}, 'test');
is($test->{database}->{dump_encoding}, 'latin1');

my $prod = $config->for_environment('prod');
is($prod->{server_group}, undef);
is($prod->{user}, 'wwwuf');
is($prod->{group}, 'webuf');
is($prod->{path}, '/nerdc/www/test.ufl.edu');
isa_ok($test->{uri}, 'URI');
is($prod->{uri}, 'http://test.ufl.edu');
is($prod->{uri}->host, 'test.ufl.edu');
is($prod->{uri}->path, '');
is($prod->{base}, '/');
is($prod->{shebang}, '#!/usr/local/bin/php');
is($prod->{exclude_robots}, 0);
is($prod->{wordpress}->{wp_cache}->{enabled}, 1);
is($prod->{wordpress}->{options}->{fake_cache_ttl}, 3600);
is($prod->{database}->{host}, 'mysql01.osg.ufl.edu');
is($prod->{database}->{port}, 3306);
is($prod->{database}->{user}, 'test');
is($prod->{database}->{password}, 'secret3');
is($prod->{database}->{name}, 'test');
is($prod->{database}->{dump_encoding}, 'latin1');

my $users = $config->users;
is_deeply($users, [ qw/akirby dwc gtmcknig mr2 trammell/ ]);

my $keys = $config->keys;
is($keys->{auth}, 'ZnZc8J/HsBOe8uPmRT+0iQxTrIRgS+/7VYb2vd87ONEircjP6cBqJ9tAhWZF+tgckfK0IpkKq7QVHhLKFqe9RQ');
is($keys->{secure_auth}, 'xY2WZ/wB6rbGkSZ9vBwecrtC4IvSRnZLsCwF2fRZ0/q+k5MBoRG9Br2reugTu/8c6a3RIL5r0uehf8iKgWD0EA');
is($keys->{logged_in}, 'QRjXU8aRda+ID08z/el3MxEImKWzJoWEA3LE+7Bcdru7iLUgkMqkTMFVK2z5mKGWiUlViibJfj2qFybqpxvoEA');
is($keys->{nonce}, 'jug9EB57ZsjIxYz3abf4gikqwBg/BgD+B+keBs9AG4VjfFRYXqGnOzx4XeyPImH7wOkP5tQGiNS26XCsu0TEyA');

my $salts = $config->salts;
is($salts->{auth}, 'rj56iqrEvtQ/T0BOlm2+4BYvPJiSk9vIAEcot+/GcZMU18lv0cOJk0F0gopOda/XLH0qbs2ahGzyfJkNRAuxzg');
is($salts->{secure_auth}, 'zrwpl7FdynLNe0WCCXkXxkG/BnRN61gNRX48A21TucO8HHPhUjZAw8AW7qoXmVgoGRREPE71KKvM5dMolNO0iQ');
is($salts->{logged_in}, 'nBB6jrifc6sVnmkgm1aE4r2hH9auomC3Jt6KhrPIApIv54JcN8xt98qRnqXh1kEICPjX/gWxeCSXguPQ5mfJrQ');
is($salts->{nonce}, '5PRfyeDCr4mVjCvzcL8nv/BNZxsKpHFtgkJSnSiQXd2tLoZ45zUswdfUV7NhDhixhAbQcPgzV3evZQHEiZTtgg');
