import { resolveEmployees, buildEmployeeList, type EmployeeConfig } from "./src/employees.js";

const workforcePlugin = {
  id: "workforce",
  name: "Workforce",
  description: "AI employee management: task creation, employee roster, and structured task lifecycle",
  configSchema: {
    parse(value: unknown): { employees: EmployeeConfig[] } {
      const raw =
        value && typeof value === "object" && !Array.isArray(value)
          ? (value as Record<string, unknown>)
          : {};
      return { employees: resolveEmployees(raw) };
    },
  },

  register(api: {
    pluginConfig?: unknown;
    logger: { info: (msg: string) => void; error: (msg: string) => void; warn: (msg: string) => void };
    registerGatewayMethod: (
      method: string,
      handler: (opts: {
        params: Record<string, unknown>;
        respond: (ok: boolean, payload?: unknown) => void;
        context: { broadcast: (event: string, payload: unknown) => void };
      }) => Promise<void> | void,
    ) => void;
  }) {
    const config = this.configSchema.parse(api.pluginConfig);
    api.logger.info(`[workforce] Registered with ${config.employees.length} employees`);

    // ── workforce.employees.list ─────────────────────────────────
    api.registerGatewayMethod("workforce.employees.list", async ({ respond }) => {
      try {
        const employees = buildEmployeeList(config.employees);
        respond(true, { employees });
      } catch (err) {
        api.logger.error(`[workforce] employees.list failed: ${err}`);
        respond(false, { error: err instanceof Error ? err.message : String(err) });
      }
    });
  },
};

export default workforcePlugin;
