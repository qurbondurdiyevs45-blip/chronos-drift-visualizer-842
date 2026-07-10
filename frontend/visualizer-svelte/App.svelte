<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  export let data: Array<{ timestamp: number; drift_ms: number }> = [];
  export let serverTime: string = "Pending...";
  export let localTime: string = "Pending...";

  let canvas: HTMLCanvasElement;
  let ctx: CanvasRenderingContext2D;
  let animationFrame: number;
  let width: number = 800;
  let height: number = 400;

  const PADDING = 40;
  const MAX_POINTS = 100;

  function draw() {
    if (!ctx) return;

    ctx.clearRect(0, 0, width, height);

    // Draw Grid
    ctx.strokeStyle = '#334155';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(PADDING, height / 2);
    ctx.lineTo(width - PADDING, height / 2);
    ctx.stroke();

    if (data.length < 2) {
      requestAnimationFrame(draw);
      return;
    }

    const points = data.slice(-MAX_POINTS);
    const maxDrift = Math.max(...points.map(p => Math.abs(p.drift_ms)), 0.1);
    const scaleY = (height / 2 - PADDING) / maxDrift;
    const scaleX = (width - 2 * PADDING) / (points.length - 1);

    // Draw Drift Line
    ctx.beginPath();
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.lineWidth = 2;
    ctx.strokeStyle = '#38bdf8';

    points.forEach((point, i) => {
      const x = PADDING + i * scaleX;
      const y = height / 2 - point.drift_ms * scaleY;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // Draw Area
    ctx.lineTo(PADDING + (points.length - 1) * scaleX, height / 2);
    ctx.lineTo(PADDING, height / 2);
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0.3, 'rgba(56, 189, 248, 0.2)');
    gradient.addColorStop(0.5, 'rgba(56, 189, 248, 0)');
    gradient.addColorStop(0.7, 'rgba(56, 189, 248, 0.2)');
    ctx.fillStyle = gradient;
    ctx.fill();

    // Latest Point Marker
    const lastPoint = points[points.length - 1];
    const lastX = PADDING + (points.length - 1) * scaleX;
    const lastY = height / 2 - lastPoint.drift_ms * scaleY;

    ctx.fillStyle = '#f87171';
    ctx.beginPath();
    ctx.arc(lastX, lastY, 4, 0, Math.PI * 2);
    ctx.fill();

    animationFrame = requestAnimationFrame(draw);
  }

  onMount(() => {
    ctx = canvas.getContext('2d')!;
    animationFrame = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(animationFrame);
  });
</script>

<main class="container">
  <header>
    <h1>Chronos Drift Visualizer</h1>
    <div class="stats-bar">
      <div class="stat">
        <span class="label">Atomic NTP:</span>
        <span class="value">{serverTime}</span>
      </div>
      <div class="stat">
        <span class="label">Hardware Clock:</span>
        <span class="value">{localTime}</span>
      </div>
      <div class="stat">
        <span class="label">Current Skew:</span>
        <span class="value drift" class:negative={data.length > 0 && data[data.length-1].drift_ms < 0}>
          {data.length > 0 ? data[data.length - 1].drift_ms.toFixed(4) : '0.0000'} ms
        </span>
      </div>
    </div>
  </header>

  <section class="visualizer">
    <canvas 
      bind:this={canvas} 
      width={width} 
      height={height}
    ></canvas>
    <div class="y-axis-labels">
      <span>+Skew</span>
      <span>0ms</span>
      <span>-Skew</span>
    </div>
  </section>
</main>

<style>
  :global(body) {
    margin: 0;
    padding: 2rem;
    background-color: #0f172a;
    color: #f8fafc;
    font-family: 'Inter', system-ui, -apple-system, sans-serif;
  }

  .container {
    max-width: 900px;
    margin: 0 auto;
  }

  header {
    margin-bottom: 2rem;
  }

  h1 {
    font-size: 1.5rem;
    font-weight: 300;
    letter-spacing: 0.05em;
    color: #94a3b8;
    text-transform: uppercase;
    margin-bottom: 1.5rem;
  }

  .stats-bar {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    background: #1e293b;
    padding: 1.5rem;
    border-radius: 8px;
    border: 1px solid #334155;
  }

  .stat {
    display: flex;
    flex-direction: column;
  }

  .label {
    font-size: 0.75rem;
    color: #64748b;
    margin-bottom: 0.25rem;
  }

  .value {
    font-family: 'JetBrains Mono', monospace;
    font-size: 1.1rem;
  }

  .drift {
    color: #4ade80;
  }

  .drift.negative {
    color: #f87171;
  }

  .visualizer {
    position: relative;
    background: #1e293b;
    border-radius: 8px;
    border: 1px solid #334155;
    margin-top: 1rem;
    overflow: hidden;
  }

  canvas {
    width: 100%;
    height: auto;
    display: block;
  }

  .y-axis-labels {
    position: absolute;
    left: 10px;
    top: 50%;
    transform: translateY(-50%);
    height: 80%;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    font-size: 0.7rem;
    color: #475569;
    pointer-events: none;
  }
</style>