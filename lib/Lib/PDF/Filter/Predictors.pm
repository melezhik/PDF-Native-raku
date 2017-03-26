use v6;

class Lib::PDF::Filter::Predictors {

    use NativeCall;
    use Lib::PDF :libpdf;
    use Lib::PDF::Buf;

    my subset BPC of UInt where 1 | 2 | 4 | 8 | 16;
    my subset Predictor of Int where 1|2|10..15;

    sub pdf_filt_predict_decode(
        Blob $in, Blob $out,
        uint8 $predictor where Predictor,
        uint8 $colors,
        uint8 $bpc where BPC,
        uint16 $columns,
        uint16 $rows,
    )  returns uint32 is native(&libpdf) { * }

    sub pdf_filt_predict_encode(
        Blob $in, Blob $out,
        uint8 $predictor where Predictor,
        uint8 $colors,
        uint8 $bpc where BPC,
        uint16 $columns,
        uint16 $rows,
    )  returns uint32 is native(&libpdf) { * }

    sub buf-type(Numeric $_) {
        when 32 { uint32 }
        when 16 { uint16 }
        default { uint8 }
    }

    sub resample(|c) {
         Lib::PDF::Buf.resample(|c);
    }
    # post prediction functions as described in the PDF 1.7 spec, table 3.8

    #| tiff predictor (2)
    multi method encode($buf where Blob | Buf, 
                        Predictor :$Predictor! where 2,   #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        BPC  :$BitsPerComponent = 8, #| number of bits per color
                       ) {
        my $rows = (+$buf * 8) div ($Columns * $Colors * $BitsPerComponent);
        my $type = buf-type($BitsPerComponent);
        my \nums := Buf[$type].new: resample( $buf, 8, $BitsPerComponent );
        my $out = nums.new;
        $out[+nums - 1] = 0
            if +nums;
	pdf_filt_predict_encode(nums, $out, $Predictor, $Colors, $BitsPerComponent, $Columns, $rows);
        buf8.new: resample( $out, $BitsPerComponent, 8);
    }

    multi method encode($buf is copy where Blob | Buf,
			Predictor :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
			UInt :$Columns = 1,          #| number of samples per row
			UInt :$Colors = 1,           #| number of colors per sample
			BPC  :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my uint $bpc = $BitsPerComponent;
        my uint $colors = $Colors;
        if $bpc > 8 {
            $colors *= $bpc div 8;
            $bpc = 8;
        }
        $buf = resample($buf, 8, $bpc)
            unless $bpc == 8;

        my uint $bit-mask = 2 ** $bpc  -  1;
        my uint $row-size = $colors * $Columns;
        my uint $ptr = 0;
        my uint8 @out;
        my uint $tag = min($Predictor - 10, 4);
        my int $n = 0;
        my int $len = +$buf;

        my $padding = do {
            my $bits-per-row = $row-size * $bpc;
            my $bit-padding = -$bits-per-row % 8;
            $bit-padding div $bpc;
        }

        my $rows = $len div $row-size;
        # preallocate, allowing room for per-row data + tag + padding
        @out[$rows * ($row-size + $padding + 1) - 1] = 0
                if $rows;

        loop (my uint $row = 0; $row < $rows; $row++) {
            @out[$n++] = $tag;

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$ptr++]
                        for 1 .. $row-size;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$ptr++] for 1 .. $colors;
                    for $colors ^.. $row-size {
                        my \left-val = $buf[$ptr - $colors];
                        @out[$n++] = ($buf[$ptr++] - left-val) +& $bit-mask;
                    }
                }
                when 2 { # Up
                    for 1 .. $row-size {
                        my \up-val = $row ?? $buf[$ptr - $row-size] !! 0;
                        @out[$n++] = ($buf[$ptr++] - up-val) +& $bit-mask;
                    }
                }
                when 3 { # Average
                   for 1 .. $row-size -> \i {
                        my \left-val = i <= $colors ?? 0 !! $buf[$ptr - $colors];
                        my \up-val = $row ?? $buf[$ptr - $row-size] !! 0;
                        @out[$n++] = ($buf[$ptr++] - ( (left-val + up-val) div 2 )) +& $bit-mask;
                   }
                }
                when 4 { # Paeth
                   for 1 .. $row-size -> \i {
                       my \left-val = i <= $colors ?? 0 !! $buf[$ptr - $colors];
                       my \up-val = $row ?? $buf[$ptr - $row-size] !! 0;
                       my \up-left-val = $row && i > $colors ?? $buf[$ptr - $row-size - $colors] !! 0;

                       my int $p = left-val + up-val - up-left-val;
                       my int $pa = abs($p - left-val);
                       my int $pb = abs($p - up-val);
                       my int $pc = abs($p - up-left-val);
                       my \nearest = do if $pa <= $pb and $pa <= $pc {
                           left-val;
                       }
                       elsif $pb <= $pc {
                           up-val;
                       }
                       else {
                           up-left-val
                       }
                       @out[$n++] = ($buf[$ptr++] - nearest) +& $bit-mask;
                   }
                }
            }

            @out[$n++] = 0
                for 0 ..^ $padding;
         }

        @out = resample(@out, $bpc, 8)
            unless $bpc == 8;
        buf8.new: @out;
    }

    # prediction filters, see PDF 1.7 spec table 3.8
    multi method encode($buf where Blob | Buf,
			Predictor :$Predictor=1, #| predictor function
        ) {
        $buf;
    }

    # prediction filters, see PDF 1.7 spec table 3.8
    multi method decode($buf where Blob | Buf, 
                        Predictor :$Predictor! where 2  , #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        UInt :$BitsPerComponent = 8, #| number of bits per color
                       ) {
        my $rows = (+$buf * 8) div ($Columns * $Colors * $BitsPerComponent);
         my $type = buf-type($BitsPerComponent);
        my \nums := Buf[$type].new: resample( $buf, 8, $BitsPerComponent );
        my $out = nums.new;
        $out[+nums - 1] = 0
            if +nums;
	pdf_filt_predict_decode(nums, $out, $Predictor, $Colors, $BitsPerComponent, $Columns, $rows);
        buf8.new: resample( $out, $BitsPerComponent, 8);
    }

    multi method decode($buf is copy,  #| input stream
                        Predictor :$Predictor! where { 10 <= $_ <= 15}, #| predictor function
                        UInt :$Columns = 1,          #| number of samples per row
                        UInt :$Colors = 1,           #| number of colors per sample
                        UInt :$BitsPerComponent = 8, #| number of bits per color
        ) {

        my uint $bpc = $BitsPerComponent;
        my uint $colors = $Colors;
        if $bpc > 8 {
            $colors *= $bpc div 8;
            $bpc = 8;
        }
        $buf = resample($buf, 8, $bpc)
            unless $bpc == 8;

        my uint $bit-mask = 2 ** $bpc  -  1;
        my uint $row-size = $colors * $Columns;
        my uint $ptr = 0;
        my uint $len = +$buf;
        my uint8 @out;
        my int $n = 0;

        my $padding = do {
            my $bits-per-row = $row-size * $bpc;
            my $bit-padding = -$bits-per-row % 8;
            $bit-padding div $bpc;
        }

        # each input row also has a tag plus any padding
        my $rows = $len div ($row-size + $padding + 1);
        # preallocate
        @out[$rows * $row-size - 1] = 0
            if $rows;

        loop (my uint $row = 0; $row < $rows; $row++) {
            # PNG prediction can vary from row to row
            my UInt $tag = $buf[$ptr++];
            $tag -= 10 if 10 <= $tag <= 14; 

            given $tag {
                when 0 { # None
                    @out[$n++] = $buf[$ptr++]
                        for 1 .. $row-size;
                }
                when 1 { # Left
                    @out[$n++] = $buf[$ptr++] for 1 .. $colors;
                    for $colors ^.. $row-size {
                        my \left-val = @out[$n - $colors];
                        @out[$n++] = ($buf[$ptr++] + left-val) +& $bit-mask;
                    }
                }
                when 2 { # Up
                    for 1 .. $row-size {
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        @out[$n++] = ($buf[$ptr++] + up-val) +& $bit-mask;
                    }
                }
                when  3 { # Average
                    for 1 .. $row-size -> \i {
                        my \left-val = i <= $colors ?? 0 !! @out[$n - $colors];
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        @out[$n++] = ($buf[$ptr++] + ( (left-val + up-val) div 2 )) +& $bit-mask;
                    }
                }
                when 4 { # Paeth
                    for 1 .. $row-size -> \i {
                        my \left-val = i <= $colors ?? 0 !! @out[$n - $colors];
                        my \up-val = $row ?? @out[$n - $row-size] !! 0;
                        my \up-left-val = $row && i > $colors ?? @out[$n - $colors - $row-size] !! 0;

                        my int $p = left-val + up-val - up-left-val;
                        my int $pa = abs($p - left-val);
                        my int $pb = abs($p - up-val);
                        my int $pc = abs($p - up-left-val);
                        my \nearest = do if $pa <= $pb and $pa <= $pc {
                            left-val;
                        }
                        elsif $pb <= $pc {
                            up-val;
                        }
                        else {
                            up-left-val
                        }

                        @out[$n++] = ($buf[$ptr++] + nearest) +& $bit-mask;
                    }
                }
                default {
                    die "bad PNG predictor tag: $_";
                }
            }

            $ptr++ for 0 ..^ $padding;
        }

        @out = resample(@out, $bpc, 8)
            unless $bpc == 8;

        buf8.new: @out;
    }

    multi method decode($buf, Predictor :$Predictor = 1, ) is default {
        $buf;
    }

}
