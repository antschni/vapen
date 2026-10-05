import { tv, type VariantProps } from "tailwind-variants";

export const buttonVariants = tv({
  base: "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-lg text-sm font-medium transition-[color,background-color,border-color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/30 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  variants: {
    variant: {
      default:
        "bg-primary text-primary-foreground shadow-card hover:bg-primary/90",
      destructive:
        "bg-destructive text-destructive-foreground shadow-card hover:bg-destructive/90 focus-visible:ring-destructive/30",
      "destructive-ghost":
        "text-destructive hover:bg-destructive/10 focus-visible:ring-destructive/30",
      outline:
        "border border-border bg-card shadow-card hover:bg-accent hover:text-accent-foreground",
      secondary:
        "bg-secondary text-secondary-foreground hover:bg-accent",
      ghost: "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
      link: "h-auto px-0 text-primary underline-offset-4 hover:underline",
    },
    size: {
      default: "h-9 px-4",
      sm: "h-8 gap-1.5 rounded-md px-3 text-[13px]",
      lg: "h-10 px-6",
      icon: "size-9",
      "icon-sm": "size-8 rounded-md",
    },
  },
  defaultVariants: {
    variant: "default",
    size: "default",
  },
});

export type ButtonVariants = VariantProps<typeof buttonVariants>;
