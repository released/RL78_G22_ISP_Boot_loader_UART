#include "custom_func.h"

void boot_main(void)
{
    hardware_init();
    while (custom_func_active())
    {
        loop();
    }
}
