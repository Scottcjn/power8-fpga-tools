#define main xvcd_server_main
#include "../xvcd/xvcd.c"
#undef main

static int failures;

int io_init(unsigned vendor, unsigned product, const char *desc)
{
    (void)vendor;
    (void)product;
    (void)desc;
    return 0;
}

int io_scan(const unsigned char *tdi, const unsigned char *tms, unsigned char *tdo, unsigned len)
{
    (void)tdi;
    (void)tms;
    (void)tdo;
    (void)len;
    return 0;
}

void io_close(void)
{
}

static void check_state(const char *label, int actual, int expected)
{
    (void)label;

    if (actual != expected) {
        failures++;
    }
}

static void test_reset_and_idle_transitions(void)
{
    check_state("reset low enters idle", jtag_step(test_logic_reset, 0), run_test_idle);
    check_state("reset high stays reset", jtag_step(test_logic_reset, 1), test_logic_reset);
    check_state("idle low stays idle", jtag_step(run_test_idle, 0), run_test_idle);
    check_state("idle high selects DR", jtag_step(run_test_idle, 1), select_dr_scan);
}

static void test_dr_scan_path(void)
{
    int state = run_test_idle;

    state = jtag_step(state, 1);
    check_state("select DR", state, select_dr_scan);
    state = jtag_step(state, 0);
    check_state("capture DR", state, capture_dr);
    state = jtag_step(state, 0);
    check_state("shift DR", state, shift_dr);
    state = jtag_step(state, 0);
    check_state("stay in shift DR", state, shift_dr);
    state = jtag_step(state, 1);
    check_state("exit DR", state, exit1_dr);
    state = jtag_step(state, 0);
    check_state("pause DR", state, pause_dr);
    state = jtag_step(state, 1);
    check_state("exit pause DR", state, exit2_dr);
    state = jtag_step(state, 1);
    check_state("update DR", state, update_dr);
    state = jtag_step(state, 0);
    check_state("return idle from DR", state, run_test_idle);
}

static void test_ir_scan_path(void)
{
    int state = run_test_idle;

    state = jtag_step(state, 1);
    check_state("select DR before IR", state, select_dr_scan);
    state = jtag_step(state, 1);
    check_state("select IR", state, select_ir_scan);
    state = jtag_step(state, 0);
    check_state("capture IR", state, capture_ir);
    state = jtag_step(state, 0);
    check_state("shift IR", state, shift_ir);
    state = jtag_step(state, 1);
    check_state("exit IR", state, exit1_ir);
    state = jtag_step(state, 1);
    check_state("update IR", state, update_ir);
    state = jtag_step(state, 0);
    check_state("return idle from IR", state, run_test_idle);
}

static void test_state_names_match_table(void)
{
    check_state("state table has every name", state_name[test_logic_reset][0] == 'R', 1);
    check_state("shift DR label", state_name[shift_dr][0] == 'D', 1);
    check_state("shift IR label", state_name[shift_ir][0] == 'I', 1);
}

int main(void)
{
    test_reset_and_idle_transitions();
    test_dr_scan_path();
    test_ir_scan_path();
    test_state_names_match_table();

    return failures == 0 ? 0 : 1;
}
