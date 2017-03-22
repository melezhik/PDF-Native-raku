use v6;
use Test;
plan 22;

use Lib::PDF::Filter::Predictors;

my $prediction-in = buf8.new: [
    0x2, 0x1, 0x0, 0x10, 0x0,
    0x2, 0x0, 0x2, 0xcd, 0x0,
    0x2, 0x0, 0x1, 0x51, 0x0,
    0x1, 0x0, 0x1, 0x70, 0x0,
    0x3, 0x0, 0x5, 0x7a, 0x0,
    0,   1,   2,   3,    4,
    ];

my $tiff-post-prediction = buf8.new: [
    0x02, 0x01, 0x00, 0x12, 0x01, 0x02, 0x12, 0x03, 0xCF, 0x12, 0x05,
    0xCF, 0x01, 0x51, 0x00, 0x02, 0x51, 0x01, 0x72, 0x51, 0x04, 0x72,
    0x56, 0x7E,
    ];

my $png-post-prediction = buf8.new: [
    0x1, 0x0, 0x10, 0x0,
    0x1, 0x2, 0xdd, 0x0,
    0x1, 0x3, 0x2e, 0x0,
    0x0, 0x1, 0x71, 0x71,
    0x0, 0x5, 0xb5, 0x93,
    1,   2,   3,    4,
    ];

is-deeply Lib::PDF::Filter::Predictors.post-prediction( $prediction-in,
                                                     :Columns(4),
                                                     :Colors(3),
                                                     :Predictor(1), ),
    $prediction-in,
    "NOOP predictive filter sanity";

my $tiff-in = buf8.new: $prediction-in.head(24);
is-deeply Lib::PDF::Filter::Predictors.post-prediction( $tiff-in,
                                                     :Columns(4),
                                                     :Colors(3),
                                                     :Predictor(2), ),
    $tiff-post-prediction,
    "TIFF predictive filter sanity";

is-deeply Lib::PDF::Filter::Predictors.post-prediction( $prediction-in,
                                                     :Columns(4),
                                                     :Predictor(12), ),
    $png-post-prediction,
    "PNG predictive filter sanity";

my $rand-data = buf8.new: [
    0x12, 0x0D, 0x12, 0x0A, 0x02, 0x47, 0x8E, 0x7A, 0x1B, 0x08, 0x28, 0x21,
    0x65, 0x5B, 0x11, 0xA0, 0x02, 0x02, 0x2F, 0x3C, 0x01, 0x4B, 0x0D, 0xC9,
    0xA0, 0x37, 0x48, 0x71, 0x0E, 0x15, 0x0B, 0x1E, 0xAE, 0x02, 0xA3, 0x31,
    0x7F, 0x01, 0x05, 0x02, 0x04, 0x08, 0x06, 0x05, 0x0F, 0xFE, 0x01, 0x1A,
    ];

for flat 1, 2, 10 .. 15 -> $Predictor {
    my $desc = do given $Predictor { when 2 { 'TIFF' }; when 1 { 'no-op'}; default {'PNG'} };

    my $prediction = Lib::PDF::Filter::Predictors.prediction( $rand-data,
                                                           :Columns(4),
                                                           :$Predictor, );

    my $post-prediction = Lib::PDF::Filter::Predictors.post-prediction( $prediction,
                                                                     :Columns(4),
                                                                     :$Predictor, );

    is-deeply $post-prediction, $rand-data, "$desc predictor ($Predictor) - appears lossless";

    my $prediction2c = Lib::PDF::Filter::Predictors.prediction( $rand-data,
								     :Columns(4),
								     :Colors(2),
								     :$Predictor, );
    
    my $post-prediction2c = Lib::PDF::Filter::Predictors.post-prediction( $prediction2c,
									 :Columns(4),
									 :Colors(2),
									 :$Predictor, );

    is-deeply $post-prediction2c, $rand-data, "$desc predictor ($Predictor) multi-channel - appears lossless";
}

my %params := { :Predictor(12), :Columns(4) };

my $rand = buf8.new: [$rand-data.list.grep({ $_ <= 0xFF })];

my $encoded;
lives-ok {$encoded = Lib::PDF::Filter::Predictors.prediction($rand, |%params)}, "%params encode with prediction";

my $decoded;
lives-ok {$decoded = Lib::PDF::Filter::Predictors.post-prediction($encoded, |%params)}, "%params encode with prediction";

is-deeply $decoded, $rand, "%params round-trip with prediction";

