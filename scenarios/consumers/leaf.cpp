#include <wil/fixture.h>
#include <fixture.h>

static_assert(wil_fixture_version == EXPECTED_VERSION, "Wrong consumer WIL include path");
static_assert(fixture_native_version == EXPECTED_VERSION, "Wrong consumer native include path");

int fixture_leaf()
{
    return wil_fixture_version;
}
