/**
 * Baseline Test Suite Runner
 * Runs the 9 automated scenarios documenting 3058ada baseline behavior.
 */

const { RealAgentHarness } = require('./loader');
const { BASELINE_SCENARIOS } = require('./scenarios');

async function runBaselineTestSuite() {
  const harness = new RealAgentHarness();
  const report = [];

  console.log('================================================================');
  console.log('   GINGA REAL AGENT (Commit 3058ada) — BASELINE TEST SUITE');
  console.log('   Ejecución 100% aislada offline sobre lógica real de backend');
  console.log('================================================================\n');

  for (const scenario of BASELINE_SCENARIOS) {
    harness.reset();
    const context = await scenario.setup(harness);
    const resultado = await scenario.ejecutar(harness, context);
    const evalResult = scenario.evaluar(resultado, harness, context);

    const record = {
      id: scenario.id,
      nombre: scenario.nombre,
      categoria: evalResult.categoria,
      baselineBug: evalResult.baselineBug || false,
      diagnostico: evalResult.diagnostico,
      replyText: resultado.replyText,
      tools: resultado.executedTools.map((t) => ({ name: t.name, args: t.args, result: t.result })),
      reservations: resultado.reservations,
    };

    report.push(record);

    const badge = evalResult.baselineBug
      ? '[!] DEFECTO BASELINE'
      : evalResult.pasa
      ? '[OK] FUNCIONA'
      : '[X] FALLO';

    console.log(`${badge} ${scenario.nombre}`);
    console.log(`    Categoría: ${evalResult.categoria}`);
    console.log(`    Diagnóstico: ${evalResult.diagnostico}`);
    if (record.tools.length > 0) {
      console.log(`    Herramientas invocadas: ${record.tools.map((t) => t.name).join(', ')}`);
    }
    console.log('');
  }

  const baselineBugs = report.filter((r) => r.baselineBug).length;
  console.log('================================================================');
  console.log(`Total escenarios evaluados: ${report.length}`);
  console.log(`Defectos de baseline documentados: ${baselineBugs}`);
  console.log('================================================================\n');

  return report;
}

if (require.main === module) {
  runBaselineTestSuite().catch((err) => {
    console.error('Error running test suite:', err);
    process.exit(1);
  });
}

module.exports = { runBaselineTestSuite };

