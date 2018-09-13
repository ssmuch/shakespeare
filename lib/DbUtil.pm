package DbUtil;

use DBI;

sub connectDb {
   my $database = shift;
   my $driver   = "SQLite"; 

   if (not defined $database) {
      $database = "db/xxgege.db";
   }

   my $dsn = "DBI:$driver:dbname=$database";
   my $dbh = DBI->connect($dsn, "", "", { RaiseError => 1 }) 
      or die $DBI::errstr;

   return $dbh;
}

sub query {
   my $dbh = shift;
   my $sql = shift;

   my $sth = $dbh->prepare($sql);
   my $rv = $sth->execute() or die $DBI::errstr;

   if($rv < 0){
      print $DBI::errstr;
   }

   return $sth->fetchrow_array();
}

sub execute {
   my $dbh = shift;
   my $sql = shift;

   my $rv = $dbh->do($sql);

   if ($rv < 0) {
      print "Failed to execute: $sql\n";
      return 1;
   }
   return 0;
}

sub closeDb {
   my $dbh = shift;
   $dbh->disconnect();
}

1;