use lib './lib';
use Utilities;

$url = "";
print Utilities::get_last_index(Utilities::get_html_href($url));