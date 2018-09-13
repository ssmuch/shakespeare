use lib './lib';
use Utilities;
use File::Fetch;
use Data::Dumper;
use LWP::Simple;
use MIME::Base64;

#$url = "";
#print Utilities::get_last_index(Utilities::get_html_href($url));

# Store img
$url      = "https://b-ssl.duitang.com/uploads/item/201406/18/20140618194053_Rzh8H.jpeg";
$content  = get($url);
$endcoded = encode_base64($content);


# Update t_image column with record
update t_image set F_content= '$endcoded' where F_name='';

# decode jpg content
$new = decode_base64($endcoded);
open(FH, '>', 'test.jpg');
binmode(FH);
print FH $new;
close FH;