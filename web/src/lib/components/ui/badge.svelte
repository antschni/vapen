<script lang="ts">
	import { cn } from '#lib/utils.js';
	import type { HTMLAttributes } from 'svelte/elements';
	import type { Snippet } from 'svelte';
	import { tv, type VariantProps } from 'tailwind-variants';

	const badgeVariants = tv({
		base: 'inline-flex h-5.5 items-center gap-1 rounded-full px-2.5 text-[11px] font-medium whitespace-nowrap [&_svg]:size-3',
		variants: {
			variant: {
				default: 'bg-primary/10 text-primary dark:bg-primary/15',
				solid: 'bg-primary text-primary-foreground',
				secondary: 'bg-muted text-muted-foreground',
				outline: 'border border-border text-muted-foreground',
				success: 'bg-success/12 text-[color-mix(in_oklch,var(--success)_75%,var(--foreground))]',
				warning: 'bg-warning/15 text-[color-mix(in_oklch,var(--warning)_60%,var(--foreground))]',
				destructive: 'bg-destructive/10 text-destructive'
			}
		},
		defaultVariants: {
			variant: 'default'
		}
	});

	type Variants = VariantProps<typeof badgeVariants>;

	type Props = HTMLAttributes<HTMLSpanElement> & {
		variant?: Variants['variant'];
		class?: string;
		children?: Snippet;
	};

	let { class: className, variant = 'default', children, ...rest }: Props = $props();
</script>

<span class={cn(badgeVariants({ variant }), className)} {...rest}>
	{@render children?.()}
</span>
