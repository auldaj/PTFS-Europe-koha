#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 1;
use Test::MockModule;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::ArticleRequests;
use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'requested() tests' => sub {

    plan tests => 5;

    $schema->storage->txn_begin;

    my $library_1 = $builder->build_object( { class => 'Koha::Libraries' } );
    my $library_2 = $builder->build_object( { class => 'Koha::Libraries' } );

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { branchcode => $library_1->id, flags => 1 } } );
    t::lib::Mocks::mock_userenv( { branchcode => $library_1 } );

    # FIXME: we moved past this pattern. This method should be refactored
    #        as ->filter_by_requested
    Koha::ArticleRequests->delete;

    my $ar_mock = Test::MockModule->new('Koha::ArticleRequest');
    $ar_mock->mock( 'notify', sub { ok( 1, '->notify() called' ); } );

    my $ar_1 = $builder->build_object(
        {   class => 'Koha::ArticleRequests',
            value => { status => Koha::ArticleRequest::Status::Requested, branchcode => $library_1->id }
        }
    );

    my $ar_2 = $builder->build_object(
        {   class => 'Koha::ArticleRequests',
            value => { status => Koha::ArticleRequest::Status::Requested, branchcode => $library_2->id }
        }
    );

    my $ar_3 = $builder->build_object(
        {   class => 'Koha::ArticleRequests',
            value => { status => Koha::ArticleRequest::Status::Pending, branchcode => $library_2->id }
        }
    );

    my $requested = Koha::ArticleRequests->requested;
    is( $requested->count,        2,                                       'Two article requests with the REQUESTED status' );
    is( $requested->next->status, Koha::ArticleRequest::Status::Requested, 'Status is correct' );
    is( $requested->next->status, Koha::ArticleRequest::Status::Requested, 'Status is correct' );

    my $requested_branch = Koha::ArticleRequests->requested( $library_1->id );
    is( $requested_branch->count, 1, 'One article request with the REQUESTED status, for the selected branchcode' );
    is( $requested_branch->next->status, Koha::ArticleRequest::Status::Requested, 'Status is correct' );

    $schema->storage->txn_rollback;
};