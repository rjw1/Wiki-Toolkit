use strict;
use Test::More tests => 27;
use CGI::Wiki;
use CGI::Wiki::TestConfig;
use DBI;

foreach my $dbtype (qw( MySQL Pg SQLite )) {

    SKIP: {
        skip "$dbtype backend not configured", 8
            unless $CGI::Wiki::TestConfig::config{$dbtype}->{dbname};

        my %config = %{$CGI::Wiki::TestConfig::config{$dbtype}};
        my $setup_class = "CGI::Wiki::Setup::$dbtype";
        eval "require $setup_class";
        my $store_class = "CGI::Wiki::Store::$dbtype";
        eval "require $store_class";
        {
            no strict 'refs';

            my $dsn = $store_class->_dsn( $config{dbname} );

            foreach my $method ( qw( cleardb setup ) ) {
                eval {
                    &{$setup_class . "::" . $method}(
                                   @config{ qw( dbname dbuser dbpass dbhost ) }
                                               );
                };
                is( $@, "",
                  "${setup_class}::$method doesn't die when called with connection details list");

                eval {
                    &{$setup_class . "::" . $method}( \% config );
                };
                is( $@, "",
               "${setup_class}::$method doesn't die when called with connection details hashref");

                eval {
                    my $dbh = DBI->connect($dsn, @config{ qw( dbuser dbpass )},
		    		           { PrintError => 0, RaiseError => 1,
				             AutoCommit => 1 } )
                      or die DBI->errstr;
                    &{$setup_class . "::" . $method}( $dbh );
                    $dbh->disconnect;
                };
                is( $@, "",
                  "${setup_class}::$method doesn't die when called with dbh");

                eval {
                    my $dbh = DBI->connect($dsn, @config{ qw( dbuser dbpass )},
		    		           { PrintError => 0, RaiseError => 1,
				             AutoCommit => 1 } )
                      or die DBI->errstr;
                    &{$setup_class . "::" . $method}( { dbh => $dbh } );
                    $dbh->disconnect;
                };
                is( $@, "",
                  "${setup_class}::$method doesn't die when called with dbh in hashref");
            }
        }
    }
}

SKIP: {
    skip "SQLite backend not configured", 3
        unless $CGI::Wiki::TestConfig::config{SQLite};

    my @mistakes = <HASH*>;
    is( scalar @mistakes, 0, "CGI::Wiki::Setup::SQLite doesn't create erroneous files called things like 'HASH(0x80fd394)'" );

    @mistakes = <ARRAY*>;
    is( scalar @mistakes, 0, "CGI::Wiki::Setup::SQLite doesn't create erroneous files called things like 'ARRAY(0x83563fc)'" );

    @mistakes = <4*>;
    is( scalar @mistakes, 0, "CGI::Wiki::Setup::SQLite doesn't create erroneous files called '4'" );
}
