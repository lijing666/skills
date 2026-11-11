import { Card } from "antd";
import type { CardProps } from "antd";
import type { ReactNode } from "react";

type SectionCardProps = Omit<CardProps, "children" | "title"> & {
  title?: string;
  description?: string;
  extra?: ReactNode;
  children: ReactNode;
};

export default function SectionCard({ title, description, extra, children, className, ...cardProps }: SectionCardProps) {
  const classes = ["jjui-section", className].filter(Boolean).join(" ");

  return (
    <Card className={classes} {...cardProps}>
      {title ? (
        <div className="jjui-section__header">
          <span className="jjui-section__title">{title}</span>
          {extra ? <div className="jjui-section__extra">{extra}</div> : null}
        </div>
      ) : null}
      {description ? <p className="jjui-section__description">{description}</p> : null}
      {children}
    </Card>
  );
}
