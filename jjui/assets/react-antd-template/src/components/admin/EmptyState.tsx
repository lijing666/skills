import { Empty } from "antd";
import type { ReactNode } from "react";

type EmptyStateProps = {
  title?: string;
  description?: string;
  action?: ReactNode;
};

export default function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <Empty
      className="jjui-empty"
      description={
        <div className="jjui-empty__body">
          {title ? <p className="jjui-empty__title">{title}</p> : null}
          {description ? <p className="jjui-empty__description">{description}</p> : null}
        </div>
      }
    >
      {action}
    </Empty>
  );
}
