use v6;
use Test;
plan 14;

use Lib::PDF::Buf;
use NativeCall;

my $buf;
my @bytes = (10, 20, 30, 40, 50, 60, 70, 80);
my $bytes := buf8.new(@bytes);

is-deeply ($buf = Lib::PDF::Buf.resample($bytes,  8, 4)), buf8.new(0, 10, 1, 4, 1, 14, 2, 8, 3, 2, 3, 12, 4, 6, 5, 0), '4 bit resample';
is-deeply Lib::PDF::Buf.resample($buf, 4, 8), $bytes, 'resample round-trip: 8 => 4 => 8';

is-deeply Lib::PDF::Buf.resample($bytes, 8, 8), $bytes, '8 bit resample';
is-deeply ($buf = Lib::PDF::Buf.resample($bytes,  8, 2)), buf8.new(0, 0, 2, 2, 0, 1, 1, 0, 0, 1, 3, 2, 0, 2, 2, 0, 0, 3, 0, 2, 0, 3, 3, 0, 1, 0, 1, 2, 1, 1, 0, 0), '2 bit resample';
is-deeply Lib::PDF::Buf.resample($buf, 2, 8), $bytes, 'resample round-trip: 8 => 2 => 8';

is-deeply Lib::PDF::Buf.resample($bytes, 8, 8), $bytes, '8 bit resample';

is-deeply ($buf=Lib::PDF::Buf.resample($bytes, 8, 16)), buf16.new(2580, 7720, 12860, 18000), '16 bit resample';
is-deeply Lib::PDF::Buf.resample($buf, 16, 8), $bytes, 'resample round-trip: 16 => 8 => 16';

is-deeply ($buf=Lib::PDF::Buf.resample($bytes[0..5], 8, 24)), buf32.new(660510, 2634300), '16 bit resample';
is-deeply Lib::PDF::Buf.resample($buf, 24, 8), buf8.new(@bytes[0..5]), 'resample round-trip: 16 => 8 => 16';

is-deeply ($buf=Lib::PDF::Buf.resample([1415192289,], 32, 8)), buf8.new(84, 90, 30, 225), '32 => 8 resample';
is-deeply ($buf= Lib::PDF::Buf.resample([2 ** 32 - 1415192289 - 1,], 32, 8)), buf8.new(255-84, 255-90, 255-30, 255-225), '32 => 8 resample (twos comp)';

my uint32 @in1[1;3] = ([10, 1318440, 12860],);
my $idx;
is-deeply ($idx=Lib::PDF::Buf.resample($bytes, 8, [1, 3, 2])).values, @in1.values, '8 => [1, 3, 2] resample';
is-deeply Lib::PDF::Buf.resample($idx, [1, 3, 2], 8), buf8.new(@bytes[0..5]), '[1, 3, 2] => 8 resample';

