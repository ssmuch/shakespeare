use lib './lib';
use Utilities;
use File::Fetch;
use Data::Dumper;
use LWP::Simple;
use MIME::Base64;

#$url = "";
#print Utilities::get_last_index(Utilities::get_html_href($url));

# Store img
#$url      = "http://p226.sezuzu.com/attachment/1703/thread/60_176891_8ce2adde7b815ec.jpg";
#$ff      = File::Fetch->new(uri => $url);
#$ff->fetch();
#$content  = get($url);
#print $content . "\n";
#$endcoded = encode_base64($content);
#update t_image set F_content= '$endcoded' where F_name='';

# decode jpg content
#$new = decode_base64($endcoded);
#open(FH, '>', 'test.jpg');
#binmode(FH);
#print FH $content;
#close FH;
$image_file = "test.jpg";
open(FH, '<', $image_file) or die "Failed to open file: $image_file\n";
binmode(FH);

while($line = <FH>) {
    $c .= $line;
}
$encoded = encode_base64($c);
close(FH);
print $encoded . "\n";

$content = decode_base64($encoded);

open(OUT, '>', 'test2.jpg');
binmode(OUT);
print OUT $content;
close OUT;