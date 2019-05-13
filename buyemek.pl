use warnings;
use strict;

use utf8;
no warnings "utf8";
binmode(STDOUT, ":utf8");
use Encode qw/decode_utf8/;

use URI;
use Furl;
use DateTime;
use Mojo::DOM;
use File::Slurper qw/write_text read_text/;

# Set up dates
my $dt = DateTime->now->set_locale('tr-TR');
print "Bugün: ". $dt->dmy . "\n";
$dt->set_day(1);

my $ym = substr($dt->ymd,0,7); # yyyy-mm
my $should_download = 1;

if (-e "$ym.html"){
  print "$ym.html daha önce indirilmiş. Yine de indirilsin mi? [e/H]: ";
  my $answer = <>;
  chomp $answer;
  $answer = lc $answer;
  $should_download = 0 unless ($answer eq 'e');
}

my $html;
if ($should_download){
  print "Dosya indiriliyor...\n";
  my $uri      = URI->new('https://yemekhane.boun.edu.tr/aylik-menu');
  my $response = Furl->new->get($uri);
  die "İndirme işlemi başarılı olamadı." unless $response && $response->is_success;
  $html = $response->content;
  write_text("$ym.html",$html);
  print "Dosya kaydedildi.\n";
} else {
  print "Dosya okunuyor...\n";
  $html = read_text("$ym.html");
  print "Dosya okundu.\n";
}

# Collect days
my $dom = Mojo::DOM->new($html);
my (@days,$lunch,$dinner);

for (qw/past today future/){
  push @days, $dom->find("td[class=single-day $_]")->to_array->@*;
}

# Collect lunch/dinner
foreach my $day (@days){
  my @lines = split("\n",$day->all_text);
  foreach my $line (@lines){
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
  }
  @lines = map { decode_utf8($_, 1) } grep {$_} @lines;
  # TODO take care of days that has only lunch or only dinner
  die "Satır sayısı 14'ten fazla!" unless scalar @lines == 14;

  my ($day_num, $day_lunch, $day_dinner);
  $day_num    = $1 if ($lines[0] =~ m/^(\d+)/);
  $day_lunch  = join("\n", @lines[2..6 ]);
  $day_dinner = join("\n", @lines[9..13]);
  $lunch->{$day_num}  = $day_lunch;
  $dinner->{$day_num} = $day_dinner;
}

# Write SQL queries
my ($list_sql, $listtek_sql);
$list_sql    = "INSERT INTO `list`    (`tweet`, `publish_on`) VALUES\n";
$listtek_sql = "INSERT INTO `listTek` (`tweet`, `publish_on`) VALUES\n";

for my $i (1..31){
  my $lunch_meal   = $lunch->{$i};
  my $dinner_meal  = $dinner->{$i};

  $dt->set_day($i);
  my $day_title    = $dt->dmy . " " . $dt->day_abbr;
  my $lunch_title  = "$day_title Ö:";
  my $dinner_title = "$day_title A:";

  my $lunch_time  = $dt->ymd . ' 10:30:00';
  my $dinner_time = $dt->ymd . ' 16:30:00';

  # One (tek) tweet a day
  if ($lunch_meal && $dinner_meal){
    $listtek_sql .= "('$lunch_title\n$lunch_meal\\n\\n$dinner_title\n$dinner_meal','$lunch_time'),\n";
  } elsif ($lunch_meal){
    $listtek_sql .= "('$lunch_title\n$lunch_meal','$lunch_time'),\n";
  } elsif ($dinner_meal){
    $listtek_sql .= "('$dinner_title\n$dinner_meal','$dinner_time'),\n";
  }

  # Two tweets a day
  if ($lunch_meal){
    $list_sql .= "('$lunch_title\n$lunch_meal','$lunch_time'),\n";
  }
  if ($dinner_meal){
    $list_sql .= "('$dinner_title\n$dinner_meal','$dinner_time'),\n";
  }
}

# TODO find a better way to handle this.
$list_sql    .= "('foo','2050-1-1'); DELETE FROM `list`    WHERE tweet = 'foo';\n";
$listtek_sql .= "('foo','2050-1-1'); DELETE FROM `listTek` WHERE tweet = 'foo';\n";

write_text("$ym.sql","$list_sql\n$listtek_sql");
print "Bitti.\n";
